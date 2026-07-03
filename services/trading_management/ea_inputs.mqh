//+------------------------------------------------------------------+
//|                               trading_management/ea_inputs.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_

// NOTE: Keep input declarations centralized to guarantee consistent defaults
// across services. Any module relying on these inputs should include this file
// (directly or through the trading_management aggregator).

// Deterministic strategy constants. Keep these internal unless a future plan
// explicitly expands the optimization surface.
const ENUM_TIMEFRAMES DETERMINISTIC_BASE_TIMEFRAME = PERIOD_M1;
const int             DETERMINISTIC_MA_PERIOD      = 21;
const int             DETERMINISTIC_STOCH_K        = 5;
const int             DETERMINISTIC_STOCH_D        = 3;
const int             DETERMINISTIC_STOCH_SLOWING  = 3;
const int             DETERMINISTIC_S1_BASE_DELAY  = 3;
const int             DETERMINISTIC_S2_BASE_DELAY  = 5;
const int             DETERMINISTIC_S3_BASE_DELAY  = 10;
const int             DETERMINISTIC_MACRO_DELAY    = 1;

// Internal compatibility defaults retained until the deterministic execution
// lifecycle fully replaces the old range/grid helpers.
ExecutionEntryStyles      Execution_Initial_Entry_Style = EXECUTION_ENTRY_STYLE_STOP;
ExecutionEntryStyles      Execution_Deep_Entry_Style    = EXECUTION_ENTRY_STYLE_STOP;
const ENUM_TIMEFRAMES     Strategy_Timeframe            = PERIOD_M1;
const int                 Stoch_Structure_Period_Type   = DETERMINISTIC_STOCH_K;
const StrategyRangeTypes  Strategy_Range_Mode           = STRATEGY_RANGE_STRUCTURE;
const double              Strategy_Range_Points         = 100.0;
const double              Min_Range_Points              = 200.0;

input group  "+= Execution Foundation EA =+";
input string EA_License_Key = "";

input group  "+= Account Settings EA =+";
input int    Custom_Magic     = 0;
input double Max_Spread       = 200.0;

input group  "+= Protection Risk Management =+";
input ProtectionRiskModes      Protection_Risk_Mode           = ENABLED_OFF;
input ProtectionRiskValueTypes Protection_Risk_Drawdown_Type  = PROTECTION_RISK_ACCOUNT_SIZE_PERCENT;
input double                   Protection_Risk_Drawdown_Value = 10.0;
input double                   Account_Size                   = 500.0;
input ENUM_TIMEFRAMES          Market_Close_Guard_Timeframe   = PERIOD_M10;

input group  "+= Time Filter Session Manager =+";
input SessionTimeFilterModes Session_Asia_Filter_Mode      = SESSION_FILTER_OFF;
input string                 Session_Asia_Filter_Time_Range = "00:00-08:00";
input SessionTimeFilterModes Session_London_Filter_Mode    = SESSION_FILTER_OFF;
input string                 Session_London_Filter_Time_Range = "07:00-12:00";
input SessionTimeFilterModes Session_NewYork_Filter_Mode   = SESSION_FILTER_OFF;
input string                 Session_NewYork_Filter_Time_Range = "12:00-20:00";
input DstOffsetModes         Session_Time_Dst_Mode         = DST_MODE_OFF;
input int                    Session_Time_Dst_Manual_Offset_Minutes = 0;

input group  "+= Deterministic Strategies =+";
input bool Enable_Strategy_1 = true;
input bool Enable_Strategy_2 = true;
input bool Enable_Strategy_3 = true;
input StrategyDirectionTypes Strategy_Direction_Mode = BOTH_DIRECTION;
input SignalConcurrencyModes Signal_Concurrency_Mode = MULTIPLE_RUNNING_SIGNALS;

input group  "+= Strategy Risk Settings =+";
input ExecutionLotTypes     Lot_Type              = EXECUTION_LOT_FIXED_SIZE;
input double                Lot_Strategy_Size     = 0.01;
input double                Lot_Multiplier        = 2.0;
input SignalLotStrategyTypes Signal_Lot_Strategy     = RISK_STRATEGY_OFF;
input double                TP_Percent               = 100.0;
input int                   Daily_Signal_Limit       = 0;
input DailySignalLimitModes Daily_Signal_Limit_Mode  = STOP_DAILY_SIGNALS;

input group  "+= Developer Debug Settings =+";
input bool Enable_Logs              = false;
input bool Enable_File_Logs         = false;
bool Enable_Show_Indicators   = true;
bool Enable_Chart_Summary     = true;
bool Enable_Chart_Levels      = true;
bool Enable_Chart_Lightweight_UI = true;
bool Enable_Chart_Ui_Debug_Logs = false;
bool Enable_Trend_Filter_Sanity_Stop = false;
bool Debug_Stop_On_Negative_Equity   = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
