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

input group  "+= Grid Strategy Settings =+";
input GridBaseStrategyTypes Grid_Base_Strategy_Type   = ATR_RANGE;
input double               Grid_ATR_Points_Setup      = 1.0;
input double               Grid_Multiplier            = 2.0;
input double               Grid_Exponential_Multiplier = 1.1;
input double               Grid_Initial_Stops_Percent = 10.0;
input double               Grid_TP_Percent            = 30.0;
input double               Grid_Trailing_TP_Percent   = 50.0;
input GridTPReferenceModes Grid_TP_Reference_Mode     = GRID_TP_REF_NEXT;
input double               Grid_Final_TP_Percent      = 200.0;
input double               Grid_Positions_Stops_Percent = 10.0;
input GridLotTypes         Grid_Lot_Type              = GRID_LOT_SIZE;
input double               Grid_Lot_Strategy_Size     = 0.01;
input GridEntryStyles      Grid_Initial_Entry_Style   = GRID_ENTRY_STYLE_STOP;
input GridEntryStyles      Grid_Deep_Entry_Style      = GRID_ENTRY_STYLE_STOP;

input group  "+= Developer Debug Settings =+";
input bool Test_Mode               = false;
input bool Hide_Indicator_Variants = true;
input bool Enable_Logs             = true;
input bool Enable_Verification_Logs = false;
input bool Enable_File_Logs        = false;
input bool Enable_Chart_Summary    = true;
input bool Enable_Chart_Levels     = true;
input int  Enable_Chart_Levels_Depth = 2;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
