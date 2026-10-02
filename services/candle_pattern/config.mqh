#ifndef CANDLE_CONFIG_MQH
#define CANDLE_CONFIG_MQH

input group "+= Candle Timeframes =+"
input BrokerSessionTimeModes Broker_Session = FIXED_TIME_SESSIONS;
input ENUM_TIMEFRAMES Macro_Timeframe = PERIOD_H1;
input ENUM_TIMEFRAMES Micro_Timeframe = PERIOD_M3;
input group "+= Broker Execution =+"
input ExecutionLotTypes Lot_Type = EXECUTION_LOT_REFERENCE_BALANCE_PERCENT;
input double Lot_Strategy_Size = 0.01;
input group "+= Signal Statistics Export =+"
input bool Enable_Signal_Feature_Export = false;
input string Signal_Feature_Run_Id = "";
#include "../model_features/continuation_inputs.mqh"
input group "+= Developer Debug =+"
input bool Enable_Logs = false;

long g_candle_magic = 0;
long g_candle_last_time = 0;
// Required by the shared Pivot execution lot planner; never use live balance.
const double PIVOT_EXECUTION_REFERENCE_BALANCE = 1000000.0;
const int CANDLE_ATR_PERIOD = 13;
const int CANDLE_BROKER_CAP = 2048;
const int CANDLE_VIRTUAL_CAP = 6144;
const int CANDLE_HISTORY_CAP = 64;

int g_atr_handle = INVALID_HANDLE;
int g_macro_seconds = 0;
int g_micro_seconds = 0;
long g_candle_sequence = 0;
datetime g_last_micro_bar = 0;
bool g_candle_stopping = false;
bool g_candle_tester_interval_completed = false;

string CandleDirection(const int direction) { return direction > 0 ? "BUY" : "SELL"; }
string CandleCategory(const int pattern_direction, const int direction)
{
  return pattern_direction == direction ? "ALIGNED" : "OPPOSED";
}

bool CandleTimeframeSupported(const ENUM_TIMEFRAMES timeframe)
{
  switch(timeframe)
  {
    case PERIOD_M1: case PERIOD_M2: case PERIOD_M3: case PERIOD_M4: case PERIOD_M5:
    case PERIOD_M6: case PERIOD_M10: case PERIOD_M12: case PERIOD_M15: case PERIOD_M20:
    case PERIOD_M30: case PERIOD_H1: case PERIOD_H2: case PERIOD_H3: case PERIOD_H4:
    case PERIOD_H6: case PERIOD_H8: case PERIOD_H12: case PERIOD_D1: case PERIOD_W1:
      return true;
  }
  return false;
}

bool CandleTickValid(const MqlTick &tick)
{
  return tick.time > 0 && tick.time_msc > 0 && ModelNumberValid(tick.bid) &&
         ModelNumberValid(tick.ask) && tick.bid > 0.0 && tick.ask >= tick.bid;
}

bool CandleAtr(double &current, double &completed, datetime &source_time, const datetime decision_time)
{
  current = EMPTY_VALUE;
  completed = EMPTY_VALUE;
  source_time = iTime(_Symbol, Micro_Timeframe, 1);
  double values[2];
  if(g_atr_handle == INVALID_HANDLE || BarsCalculated(g_atr_handle) <= CANDLE_ATR_PERIOD ||
     CopyBuffer(g_atr_handle, 0, 0, 2, values) != 2 || source_time <= 0 ||
     source_time + g_micro_seconds > decision_time)
    return false;
  if(ModelNumberValid(values[1]) && values[1] > 0.0) current = values[1];
  if(ModelNumberValid(values[0]) && values[0] > 0.0) completed = values[0];
  return completed != EMPTY_VALUE;
}

#endif
