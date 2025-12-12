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

input group  "+= PANDORA BOX EA V1.0 =+";
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

input group  "+= Pandora Box Strategy =+";
 bool   Pandora_Box_Enable             = true;
input string Pandora_Box_Time_Range         = "13:00-14:29";
input double Pandora_Box_Max_Range_Points   = 0.0;
input double Pandora_Box_Offset_Points      = 50.0;
input double Pandora_Points_SL              = 100.0;
input double Pandora_Points_TP              = 100.0;
input bool   Pandora_Box_Stop_On_First_Win  = false;
input StrategyDirectionTypes Pandora_Box_Direction_Mode = BOTH_DIRECTION;
input bool   Pandora_Box_Stop_After_Sides   = true;
input bool   Pandora_Box_Use_Session_Filter = true;
input bool   Pandora_Box_Enable_Visualization = true;
 color  Pandora_Box_Color              = clrDodgerBlue;
 color  Pandora_Box_Invalid_Color      = clrFireBrick;
 color  Pandora_Box_Breakout_Color     = clrDarkOrange;
 int    Pandora_Box_Line_Style         = STYLE_DASH;
 int    Pandora_Box_Breakout_Line_Style = STYLE_DASHDOT;

//input group  "+= Strategy Context =+";
 ENUM_TIMEFRAMES           Strategy_Timeframe          = PERIOD_M1;
 ENUM_TIMEFRAMES           Trend_Strategy_Timeframe    = PERIOD_CURRENT;
 ENUM_TIMEFRAMES           Macro_Strategy_Timeframe    = PERIOD_CURRENT;
 ENUM_TIMEFRAMES           Session_Strategy_Timeframe  = PERIOD_CURRENT;
 BaseIndicatorPeriodTypes  Base_Indicator_Period_Type  = BASE_PERIOD_21;
 ENUM_MA_METHOD            Base_Indicator_MA_Method    = MODE_EMA;
 StochStructurePeriodTypes Stoch_Structure_Period_Type = STOCH_STRUCTURE_PERIOD_5;
 StrategyDirectionTypes    Strategy_Direction_Mode     = BOTH_DIRECTION;
 ChannelIndicatorTypes     Strategy_Channel_Indicator_Type = CHANNEL_INDICATOR_BOLLINGER;
 IndicatorShiftTypes       Strategy_Channel_Indicator_Shift = INDICATOR_SHIFT_0;
 StrategyEntryChannelModes Strategy_Global_Channel_Entry_Mode = ENTRY_MODE_MA_TREND;
 StrategyGlobalStochEntryModes Strategy_Global_Stoch_Entry_Mode = STOCH_ENTRY_OFF;
 SignalConcurrencyModes    Signal_Concurrency_Mode     = SINGLE_RUNNING_SIGNAL;
 int                       Alligator_Jaws_Period       = 233;

//input group "+= Strategy Base Context =+";
 StrategyTrendModes          Strategy_Base_Trend_Mode          = TREND_OFF;
 StrategyEntryChannelModes Strategy_Base_Entry_Evaluation   = ENTRY_EVAL_OFF;
 BodyVolumeFilterModes       Base_Body_Volume_Filter           = BODY_VOLUME_OFF;
 TrendStructureFilterModes   Base_First_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Base_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
 TrendStructureFilterModes   Base_Third_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Base_Fourth_Structure_Filter      = BEARISH_STRUCT_OFF;
 SupportRetestFilterModes    Base_Support_Filter               = SUPPORT_DISABLED;
 ResistanceRetestFilterModes Base_Resistance_Filter            = RESISTANCE_DISABLED;
 int                         Base_Support_Retest_Min_Count     = 1;
 int                         Base_Resistance_Retest_Min_Count  = 1;
 int                         Base_Min_Extern_Structures_Broken = 0;
 bool                        Base_First_Structure_Close_Percent = false;
 bool                        Base_Fresh_Structure_Time         = false;
 bool                        Base_BPercent_Slope_Filter        = false;
 bool                        Base_Stochastic_Slope_Filter      = false;
 bool                        Base_Alligator_Slope_Filter       = false;
 bool                        Base_Channel_MA_Filter            = false;

//input group "+= Strategy Trend Context =+";
 StrategyTrendModes          Strategy_Trend_Trend_Mode          = TREND_OFF;
 StrategyEntryChannelModes Strategy_Trend_Entry_Evaluation   = ENTRY_EVAL_OFF;
 BodyVolumeFilterModes       Trend_Body_Volume_Filter           = BODY_VOLUME_OFF;
 TrendStructureFilterModes   Trend_First_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Trend_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
 TrendStructureFilterModes   Trend_Third_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Trend_Fourth_Structure_Filter      = BEARISH_STRUCT_OFF;
 SupportRetestFilterModes    Trend_Support_Filter               = SUPPORT_DISABLED;
 ResistanceRetestFilterModes Trend_Resistance_Filter            = RESISTANCE_DISABLED;
 int                         Trend_Support_Retest_Min_Count     = 1;
 int                         Trend_Resistance_Retest_Min_Count  = 1;
 int                         Trend_Min_Extern_Structures_Broken = 0;
 bool                        Trend_First_Structure_Close_Percent = false;
 bool                        Trend_Fresh_Structure_Time         = false;
 bool                        Trend_BPercent_Slope_Filter        = false;
 bool                        Trend_Stochastic_Slope_Filter      = false;
 bool                        Trend_Alligator_Slope_Filter       = false;
 bool                        Trend_Channel_MA_Filter            = false;

//input group "+= Strategy Macro Context =+";
 StrategyTrendModes          Strategy_Macro_Trend_Mode          = TREND_OFF;
 StrategyEntryChannelModes Strategy_Macro_Entry_Evaluation   = ENTRY_EVAL_OFF;
 BodyVolumeFilterModes       Macro_Body_Volume_Filter           = BODY_VOLUME_OFF;
 TrendStructureFilterModes   Macro_First_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Macro_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
 TrendStructureFilterModes   Macro_Third_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Macro_Fourth_Structure_Filter      = BEARISH_STRUCT_OFF;
 SupportRetestFilterModes    Macro_Support_Filter               = SUPPORT_DISABLED;
 ResistanceRetestFilterModes Macro_Resistance_Filter            = RESISTANCE_DISABLED;
 int                         Macro_Support_Retest_Min_Count     = 1;
 int                         Macro_Resistance_Retest_Min_Count  = 1;
 int                         Macro_Min_Extern_Structures_Broken = 0;
 bool                        Macro_First_Structure_Close_Percent = false;
 bool                        Macro_Fresh_Structure_Time         = false;
 bool                        Macro_BPercent_Slope_Filter        = false;
 bool                        Macro_Stochastic_Slope_Filter      = false;
 bool                        Macro_Alligator_Slope_Filter       = false;
 bool                        Macro_Channel_MA_Filter            = false;

//input group "+= Strategy Session Context =+";
 StrategyTrendModes          Strategy_Session_Trend_Mode        = TREND_OFF;
 StrategyEntryChannelModes Strategy_Session_Entry_Evaluation = ENTRY_EVAL_OFF;
 BodyVolumeFilterModes       Session_Body_Volume_Filter          = BODY_VOLUME_OFF;
 TrendStructureFilterModes   Session_First_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Session_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
 TrendStructureFilterModes   Session_Third_Structure_Filter       = BULLISH_STRUCT_OFF;
 TrendStructureFilterModes   Session_Fourth_Structure_Filter      = BEARISH_STRUCT_OFF;
 SupportRetestFilterModes    Session_Support_Filter               = SUPPORT_DISABLED;
 ResistanceRetestFilterModes Session_Resistance_Filter            = RESISTANCE_DISABLED;
 int                         Session_Support_Retest_Min_Count     = 1;
 int                         Session_Resistance_Retest_Min_Count  = 1;
 int                         Session_Min_Extern_Structures_Broken = 0;
 bool                        Session_First_Structure_Close_Percent = false;
 bool                        Session_Fresh_Structure_Time         = false;
 bool                        Session_BPercent_Slope_Filter        = false;
 bool                        Session_Stochastic_Slope_Filter      = false;
 bool                        Session_Alligator_Slope_Filter       = false;
 bool                        Session_Channel_MA_Filter            = false;

//input group  "+= Grid Strategy Settings =+";
 GridBaseStrategyTypes Grid_Base_Strategy_Type      = CHANNEL_INDICATOR_RANGE;
 double                Grid_Points_Range_Setup      = 100.0;
 double                Grid_Channel_Factor          = 1.0;
 double                Grid_Channel_Evaluation_Factor = 0.0;
 double                Grid_Channel_Volatility_Factor = 0.0;
 double                Grid_Points_TP               = 100.0;
 double                Grid_Exponential_Multiplier  = 1.0;
 double                Grid_Positions_Stops_Percent = 10.0;
 double                Grid_Final_TP_Percent        = 200.0;
 bool                  Grid_Enable_Robust_TP        = false;
 bool                  Grid_Enable_Scalper_TP       = false;
 bool                  Grid_Enable_Aggressive_TP    = false;

input group  "+= Grid Risk Managment Settings =+";
input GridLotTypes         Grid_Lot_Type                 = GRID_LOT_SIZE;
input double               Grid_Lot_Strategy_Size        = 0.01;
 double               Grid_Lot_Multiplier           = 2.0;
 int                  Grid_Level_Position_Start     = 0;
 int                  Grid_Level_Stop_Limit         = 0;
 int                  Daily_Signal_Limit            = 0;
 DailySignalLimitModes Daily_Signal_Limit_Mode      = STOP_DAILY_SIGNALS;

//input group  "+= Grid Trend Risk Strategy =+";
 GridRiskTrendModes   Grid_Risk_Trend_Mode          = GRID_RM_TREND_OFF;
 GridRiskAlligatorReferenceModes Grid_Risk_Alligator_Reference = GRID_RISK_REF_JAWS;
 GridRiskTrendTimeframeSources   Grid_Risk_Timeframe_Source    = GRID_RISK_TF_TREND;
 ENUM_TIMEFRAMES      Grid_Risk_Trend_Timeframe     = PERIOD_CURRENT;
 double               Grid_Risk_Trend_Hedge_Points  = 0.0;
 bool                 Grid_Risk_Trend_Hedge_SL      = true;
 int                  Grid_Risk_Trend_Hedge_Level_Cover = 5;

//input group  "+= Grid Trailing Strategy Settings =+";
 double                 Grid_TP_Percent              = 100.0;
 double                 Grid_Trailing_TP_Percent     = 10.0;
 ENUM_TIMEFRAMES        Grid_Trailing_Timeframe      = PERIOD_CURRENT;
 TrailingStrategyModes  Grid_Trailing_Strategy_Mode  = TRAILING_DEFAULT;
 TrailingExecutionModes Grid_Trailing_Execution_Mode = TRAILING_EXECUTION_DEFAULT;
 BreakEvenModes         Grid_BreakEven_Mode          = BE_DISABLE;
 double                 Grid_Partial_Take_Percentage = 50.0;

//input group  "+= Developer Debug Settings =+";
 bool Enable_Logs              = false;
 bool Enable_File_Logs         = false;
 bool Enable_Show_Indicators   = true;
 bool Enable_Chart_Summary     = true;
 bool Enable_Chart_Levels      = true;
 bool Enable_Trend_Filter_Sanity_Stop = false;
 bool Debug_Stop_On_Negative_Equity   = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
