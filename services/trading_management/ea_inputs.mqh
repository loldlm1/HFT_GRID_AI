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

input group  "+= TC HFT Grid AI EA V1.0 =+";
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

input group  "+= Strategy Context =+";
input ENUM_TIMEFRAMES           Strategy_Timeframe          = PERIOD_M1;
input ENUM_TIMEFRAMES           Trend_Strategy_Timeframe    = PERIOD_CURRENT;
input BaseIndicatorPeriodTypes  Base_Indicator_Period_Type  = BASE_PERIOD_21;
input ENUM_MA_METHOD            Base_Indicator_MA_Method    = MODE_EMA;
input SolidIndicatorPeriodTypes Solid_Indicator_Period_Type = SOLID_PERIOD_5;
input StrategyDirectionTypes    Strategy_Direction_Mode     = BOTH_DIRECTION;

input group "+= Strategy Base Context =+";
input double                      Base_Indicator_Percent            = 50.0;
input TrendStructureFilterModes   Base_First_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Base_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
input SupportRetestFilterModes    Base_Support_Filter               = SUPPORT_DISABLED;
input ResistanceRetestFilterModes Base_Resistance_Filter            = RESISTANCE_DISABLED;
input int                         Base_Min_Extern_Structures_Broken = 0;
input bool                        Base_Fresh_Structure_Time         = false;

input group "+= Strategy Trend Context =+";
input StrategyTrendModes          Strategy_Trend_Mode                = TREND_OFF;
input double                      Trend_Indicator_Percent            = 50.0;
input TrendStructureFilterModes   Trend_First_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Trend_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
input SupportRetestFilterModes    Trend_Support_Filter               = SUPPORT_DISABLED;
input ResistanceRetestFilterModes Trend_Resistance_Filter            = RESISTANCE_DISABLED;
input int                         Trend_Min_Extern_Structures_Broken = 0;
input bool                        Trend_Fresh_Structure_Time         = false;

input group  "+= Grid Strategy Settings =+";
input GridBaseStrategyTypes Grid_Base_Strategy_Type      = ATR_RANGE;
input double                Grid_ATR_Points_Setup        = 1.0;
input double                Grid_Exponential_Multiplier  = 1.0;
input double                Grid_Positions_Stops_Percent = 10.0;
input double                Grid_Final_TP_Percent        = 200.0;
input double                Grid_TP_Percent              = 100.0;
input double                Grid_Trailing_TP_Percent     = 50.0;
input bool                  Grid_Enable_Robust_TP        = false;

input group  "+= Grid Risk Managment Settings =+";
input GridLotTypes         Grid_Lot_Type                 = GRID_LOT_SIZE;
input double               Grid_Lot_Strategy_Size        = 0.01;
input double               Grid_Lot_Multiplier           = 2.0;

input group  "+= Developer Debug Settings =+";
input bool Enable_Logs              = false;
input bool Enable_File_Logs         = false;
input bool Enable_Show_Indicators   = true;
input bool Enable_Chart_Summary     = true;
input bool Enable_Chart_Levels      = true;
input bool Enable_Trend_Filter_Sanity_Stop = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
