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
input ENUM_TIMEFRAMES           Macro_Strategy_Timeframe    = PERIOD_CURRENT;
input ENUM_TIMEFRAMES           Session_Strategy_Timeframe  = PERIOD_CURRENT;
input BaseIndicatorPeriodTypes  Base_Indicator_Period_Type  = BASE_PERIOD_21;
input ENUM_MA_METHOD            Base_Indicator_MA_Method    = MODE_EMA;
input StochStructurePeriodTypes Stoch_Structure_Period_Type = STOCH_STRUCTURE_PERIOD_5;
input StrategyDirectionTypes    Strategy_Direction_Mode     = BOTH_DIRECTION;
input SignalConcurrencyModes    Signal_Concurrency_Mode     = SINGLE_RUNNING_SIGNAL;
input int                       Alligator_Jaws_Period       = 233;

input group "+= Strategy Base Context =+";
input StrategyTrendModes          Strategy_Base_Mode                = TREND_BPERCENT_WINDOW_AND_MEAN;
input double                      Base_Indicator_Percent            = 50.0;
input TrendStructureFilterModes   Base_First_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Base_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
input SupportRetestFilterModes    Base_Support_Filter               = SUPPORT_DISABLED;
input ResistanceRetestFilterModes Base_Resistance_Filter            = RESISTANCE_DISABLED;
input int                         Base_Support_Retest_Min_Count     = 1;
input int                         Base_Resistance_Retest_Min_Count  = 1;
input int                         Base_Min_Extern_Structures_Broken = 0;
input bool                        Base_Fresh_Structure_Time         = false;
input bool                        Base_BPercent_Slope_Filter        = false;
input bool                        Base_Stochastic_Slope_Filter      = false;
input bool                        Base_Alligator_Slope_Filter       = false;
input bool                        Base_Channel_MA_Filter            = false;

input group "+= Strategy Trend Context =+";
input StrategyTrendModes          Strategy_Trend_Mode                = TREND_OFF;
input double                      Trend_Indicator_Percent            = 50.0;
input TrendStructureFilterModes   Trend_First_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Trend_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
input SupportRetestFilterModes    Trend_Support_Filter               = SUPPORT_DISABLED;
input ResistanceRetestFilterModes Trend_Resistance_Filter            = RESISTANCE_DISABLED;
input int                         Trend_Support_Retest_Min_Count     = 1;
input int                         Trend_Resistance_Retest_Min_Count  = 1;
input int                         Trend_Min_Extern_Structures_Broken = 0;
input bool                        Trend_Fresh_Structure_Time         = false;
input bool                        Trend_BPercent_Slope_Filter        = false;
input bool                        Trend_Stochastic_Slope_Filter      = false;
input bool                        Trend_Alligator_Slope_Filter       = false;
input bool                        Trend_Channel_MA_Filter            = false;

input group "+= Strategy Macro Context =+";
input StrategyTrendModes          Strategy_Macro_Mode                = TREND_OFF;
input double                      Macro_Indicator_Percent            = 50.0;
input TrendStructureFilterModes   Macro_First_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Macro_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
input SupportRetestFilterModes    Macro_Support_Filter               = SUPPORT_DISABLED;
input ResistanceRetestFilterModes Macro_Resistance_Filter            = RESISTANCE_DISABLED;
input int                         Macro_Support_Retest_Min_Count     = 1;
input int                         Macro_Resistance_Retest_Min_Count  = 1;
input int                         Macro_Min_Extern_Structures_Broken = 0;
input bool                        Macro_Fresh_Structure_Time         = false;
input bool                        Macro_BPercent_Slope_Filter        = false;
input bool                        Macro_Stochastic_Slope_Filter      = false;
input bool                        Macro_Alligator_Slope_Filter       = false;
input bool                        Macro_Channel_MA_Filter            = false;

input group "+= Strategy Session Context =+";
input StrategyTrendModes          Strategy_Session_Mode                = TREND_OFF;
input double                      Session_Indicator_Percent            = 50.0;
input TrendStructureFilterModes   Session_First_Structure_Filter       = BULLISH_STRUCT_OFF;
input TrendStructureFilterModes   Session_Second_Structure_Filter      = BEARISH_STRUCT_OFF;
input SupportRetestFilterModes    Session_Support_Filter               = SUPPORT_DISABLED;
input ResistanceRetestFilterModes Session_Resistance_Filter            = RESISTANCE_DISABLED;
input int                         Session_Support_Retest_Min_Count     = 1;
input int                         Session_Resistance_Retest_Min_Count  = 1;
input int                         Session_Min_Extern_Structures_Broken = 0;
input bool                        Session_Fresh_Structure_Time         = false;
input bool                        Session_BPercent_Slope_Filter        = false;
input bool                        Session_Stochastic_Slope_Filter      = false;
input bool                        Session_Alligator_Slope_Filter       = false;
input bool                        Session_Channel_MA_Filter            = false;

input group  "+= Grid Strategy Settings =+";
input GridBaseStrategyTypes Grid_Base_Strategy_Type      = ATR_RANGE;
input double                Grid_Points_Range_Setup      = 100.0;
input double                Grid_Channel_Factor          = 1.0;
input double                Grid_Points_TP               = 0.0;
input double                Grid_Exponential_Multiplier  = 1.0;
input double                Grid_Positions_Stops_Percent = 10.0;
input double                Grid_Final_TP_Percent        = 200.0;
input bool                  Grid_Enable_Robust_TP        = false;
input bool                  Grid_Enable_Scalper_TP       = false;
input bool                  Grid_Enable_Aggressive_TP    = false;

input group  "+= Grid Risk Managment Settings =+";
input GridLotTypes         Grid_Lot_Type                 = GRID_LOT_SIZE;
input double               Grid_Lot_Strategy_Size        = 0.01;
input double               Grid_Lot_Multiplier           = 2.0;
input int                  Grid_Level_Stop_Limit         = 0;
input int                  Daily_Signal_Limit            = 0;
input DailySignalLimitModes Daily_Signal_Limit_Mode      = STOP_DAILY_SIGNALS;
input GridRiskTrendModes   Grid_Risk_Trend_Mode          = GRID_RM_TREND_OFF;
input GridRiskAlligatorReferenceModes Grid_Risk_Alligator_Reference = GRID_RISK_REF_JAWS;
input GridRiskTrendTimeframeSources   Grid_Risk_Timeframe_Source    = GRID_RISK_TF_TREND;

input group  "+= Grid Trailing Strategy Settings =+";
input double                 Grid_TP_Percent              = 100.0;
input double                 Grid_Trailing_TP_Percent     = 10.0;
input ENUM_TIMEFRAMES        Grid_Trailing_Timeframe      = PERIOD_CURRENT;
input TrailingStrategyModes  Grid_Trailing_Strategy_Mode  = TRAILING_DEFAULT;
input TrailingExecutionModes Grid_Trailing_Execution_Mode = TRAILING_EXECUTION_DEFAULT;
input BreakEvenModes         Grid_BreakEven_Mode          = BE_DISABLE;
input double                 Grid_Partial_Take_Percentage = 50.0;

input group  "+= Developer Debug Settings =+";
input bool Enable_Logs              = false;
input bool Enable_File_Logs         = false;
input bool Enable_Show_Indicators   = true;
input bool Enable_Chart_Summary     = true;
input bool Enable_Chart_Levels      = true;
input bool Enable_Trend_Filter_Sanity_Stop = false;
input bool Debug_Stop_On_Negative_Equity   = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
