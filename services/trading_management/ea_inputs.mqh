//+------------------------------------------------------------------+
//|                               trading_management/ea_inputs.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_

input group "+= License =+";
input string EA_License_Key = "";

input group "+= Pivot HFT Strategy =+";
input ENUM_TIMEFRAMES        Pivot_HFT_Micro_Timeframe      = PERIOD_M1;
input ENUM_TIMEFRAMES        Pivot_HFT_Pivot_Timeframe      = PERIOD_M30;
input StrategyDirectionTypes Pivot_HFT_Direction_Mode       = BOTH_DIRECTION;
input double                 Pivot_HFT_Retracement_Points   = 25.0;
input PivotHftLocalSlModes   Pivot_HFT_Local_SL_Mode        = PIVOT_HFT_LOCAL_SL_POINTS;
input double                 Pivot_HFT_Local_SL_Points      = 25.0;
input double                 Pivot_HFT_Local_SL_Bands_Width_Percent = 25.0;
input double                 Pivot_HFT_TP_Step_Points       = 25.0;
input double                 Pivot_HFT_TP_Step_SL_Ratio     = 0.0;
input double                 Pivot_HFT_Fixed_TP_SL_Ratio    = 0.0;
input double                 Pivot_HFT_Lot_Size             = 0.01;
input bool                   Pivot_HFT_Enable_Visualization = true;

input group "+= Account And Execution =+";
input int    Custom_Magic   = 0;
input string EA_Instance_Id = "";
input double Max_Spread     = 200.0;

input group "+= Protection Risk Management =+";
input ProtectionRiskModes      Protection_Risk_Mode          = PROTECTION_DISABLED;
input ProtectionRiskValueTypes Protection_Risk_Drawdown_Type = PROTECTION_RISK_ACCOUNT_SIZE_PERCENT;
input double                   Protection_Risk_Drawdown_Value = 10.0;
input double                   Account_Size                   = 500.0;
ENUM_TIMEFRAMES                Market_Close_Guard_Timeframe  = PERIOD_M10;

input group "+= Session Filters =+";
input SessionTimeFilterModes Session_Asia_Filter_Mode          = SESSION_FILTER_OFF;
input string                 Session_Asia_Filter_Time_Range    = "13:30-15:00";
input SessionTimeFilterModes Session_London_Filter_Mode        = SESSION_FILTER_OFF;
input string                 Session_London_Filter_Time_Range  = "07:00-12:00";
input SessionTimeFilterModes Session_NewYork_Filter_Mode       = SESSION_FILTER_OFF;
input string                 Session_NewYork_Filter_Time_Range = "12:00-20:00";
input DstOffsetModes         Session_Time_Dst_Mode             = DST_MODE_AUTO_EXNESS;
input int                    Session_Time_Dst_Manual_Offset_Minutes = 0;

input group "+= Daily Limits =+";
input int                   Daily_Signal_Limit      = 0;
input DailySignalLimitModes Daily_Signal_Limit_Mode = STOP_DAILY_SIGNALS;

input group "+= Diagnostics =+";
input bool Enable_Logs                    = false;
input bool Enable_File_Logs               = false;
input bool Debug_Stop_On_Negative_Equity = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
