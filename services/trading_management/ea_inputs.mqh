//+------------------------------------------------------------------+
//|                               trading_management/ea_inputs.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_

// NOTE: Keep input declarations centralized to guarantee consistent defaults
// across services. Any module relying on these inputs should include this file
// (directly or through the trading_management aggregator).

// DEFAULT VALUES (can be inputs)
GridEntryStyles      Grid_Initial_Entry_Style = GRID_ENTRY_STYLE_STOP;
GridEntryStyles      Grid_Deep_Entry_Style    = GRID_ENTRY_STYLE_STOP;

input group  "+= Fibonacci EA V1.0 =+";
input string EA_License_Key = "";

input group  "+= Account Settings EA =+";
input int    Custom_Magic     = 0;
input double Max_Spread       = 200.0;
input double Min_Range_Points = 200.0;

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

input group  "+= Strategy Context =+";
input ENUM_TIMEFRAMES           Strategy_Timeframe          = PERIOD_M1;
input int                       Stoch_Structure_Period_Type = 5;
input string                    Structure_Fibonacci_Levels = "23.6,38.2,50.0,61.8,78.6,100.0";
input StructureTriggerEntryModes Structure_Trigger_Entry   = LEVELS_AS_LIMITS;
input StructureTouchPolicyModes Structure_Touch_Policy     = ALLOW_RETEST;
input StrategyDirectionTypes    Strategy_Direction_Mode     = BOTH_DIRECTION;
input SignalConcurrencyModes    Signal_Concurrency_Mode     = SINGLE_RUNNING_SIGNAL;

input group  "+= Candle Structure Filter =+";
input ENUM_TIMEFRAMES   Candle_Timeframe      = PERIOD_M15;
input CandleStrategyTypes Candle_Strategy_Type = OFF_CANDLE_STRUCTURE;
input int               Candle_Strategy_Shift = 0;
input int               Candle_Strategy_Depth = 1;

input group  "+= Support Resistance Retest Chain =+";
input bool   Support_Resistance_Retest_Chain_Enabled       = false;
input int    Support_Resistance_Retest_Chain_Count         = 1;
input double Support_Resistance_Retest_Chain_Range_Percent = 10.0;

input group  "+= Structure Trailing Addon =+";
input TrailingStructureModes Trailing_Structure_Mode       = TRAILING_OFF;
input double                Trailing_TP_Close_Percent      = 0.0;

input group "+= Structure Compound Context =+";
input TrendStructureCompoundModes Base_Structure_Compound_Filter    = COMPOUND_MODE_OFF;
input bool                        Base_Fresh_Structure_Time         = false;

input group  "+= Grid Strategy Settings =+";
input double                Grid_Exponential_Multiplier  = 1.0;
input int                   Grid_Level_Position_Start    = 0;
input int                   Grid_Level_Stop_Limit        = 1;

input group  "+= Risk Managment Settings =+";
input GridBaseStrategyTypes Base_Strategy_Type       = FIB_LEVEL_RANGE;
input double                Points_Range_Setup       = 100.0;
input GridLotTypes          Lot_Type                 = GRID_LOT_SIZE;
input double                Lot_Strategy_Size        = 0.01;
input double                Lot_Multiplier           = 2.0;
input SignalLotStrategyTypes Signal_Lot_Strategy     = RISK_STRATEGY_OFF;
input double                TP_Percent               = 100.0;
input int                   Daily_Signal_Limit       = 0;
input DailySignalLimitModes Daily_Signal_Limit_Mode  = STOP_DAILY_SIGNALS;

//input group  "+= Developer Debug Settings =+";
bool Enable_Logs              = false;
bool Enable_File_Logs         = false;
bool Enable_Show_Indicators   = true;
bool Enable_Chart_Summary     = true;
bool Enable_Chart_Levels      = true;
bool Enable_Chart_Lightweight_UI = true;
bool Enable_Chart_Ui_Debug_Logs = false;
bool Enable_Trend_Filter_Sanity_Stop = false;
bool Debug_Stop_On_Negative_Equity   = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
