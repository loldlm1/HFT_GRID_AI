//+------------------------------------------------------------------+
//|                               trading_management/ea_inputs.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_

// NOTE: Keep input declarations centralized to guarantee consistent defaults
// across services. Any module relying on these inputs should include this file
// (directly or through the trading_management aggregator).

// The intrinsic extremum engine is intentionally fixed to M1 for this phase.
const ENUM_TIMEFRAMES EXTREMUM_ENGINE_TIMEFRAME    = PERIOD_M1;
const int             DETERMINISTIC_MA_PERIOD      = 21;
const int             DETERMINISTIC_STOCH_K        = 5;
const int             DETERMINISTIC_STOCH_D        = 3;
const int             DETERMINISTIC_STOCH_SLOWING  = 3;
const double          DETERMINISTIC_B_PERCENT_DEVIATION = 2.0;

input group  "+= Market Data Time =+";
input BrokerSessionTimeModes Broker_Session = FIXED_TIME_SESSIONS;

input group  "+= Broker Execution =+";
input ExecutionLotTypes Lot_Type          = EXECUTION_LOT_FIXED_SIZE;
input double            Lot_Strategy_Size = 0.01;

input group  "+= Signal Statistics Export =+";
input bool   Enable_Signal_Feature_Export = false;
input string Signal_Feature_Run_Id        = "";

input group  "+= ML Shadow Inference =+";
input MLInferenceModes ML_Inference_Mode = ML_INFERENCE_DISABLED;
input string           ML_Model_Export_Id = "xgb_test_1_export_v1";

input group  "+= Pattern Audit Playback =+";
input bool   Enable_Pattern_Audit_Overlay = false;
input string Pattern_Audit_Set_Id         = "";

input group  "+= Developer Debug Settings =+";
input bool Enable_Logs              = false;
input bool Enable_File_Logs         = false;
bool Debug_Stop_On_Negative_Equity   = false;

#endif // _SERVICES_TRADING_MANAGEMENT_EA_INPUTS_MQH_
