//+------------------------------------------------------------------+
//|                  hedged_alligator_state.mqh                      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_HEDGED_ALLIGATOR_STATE_MQH_
#define _SERVICES_TRADING_SIGNALS_HEDGED_ALLIGATOR_STATE_MQH_

struct HedgedAlligatorState
{
  double jaws;
  double teeth;
  double lips;
  bool   valid;
  HedgedAlligatorTrendPhase phase;
  SignalTypes trend_direction;
  ENUM_TIMEFRAMES tf;

  HedgedAlligatorState()
  {
    jaws = 0.0;
    teeth = 0.0;
    lips = 0.0;
    valid = false;
    phase = HEDGED_TREND_PHASE_UNKNOWN;
    trend_direction = NO_SIGNAL;
    tf = PERIOD_CURRENT;
  }
};

int g_hedged_alligator_handle = INVALID_HANDLE;
ENUM_TIMEFRAMES g_hedged_alligator_tf = PERIOD_CURRENT;

bool HedgedEnsureAlligatorHandle(const ENUM_TIMEFRAMES tf)
{
  if(g_hedged_alligator_handle != INVALID_HANDLE && g_hedged_alligator_tf == tf)
    return true;

  g_hedged_alligator_handle = iAlligator(_Symbol,
                                         tf,
                                         233, 0,   // jaws period/shift
                                         34, 0,    // teeth period/shift
                                         5, 0,     // lips period/shift
                                         Hedged_Alligator_Ma_Method,
                                         PRICE_WEIGHTED);
  g_hedged_alligator_tf = tf;

  if(g_hedged_alligator_handle == INVALID_HANDLE)
  {
    Print("ERROR loading hedged alligator handle: ", GetLastError());
    if(MQLInfoInteger(MQL_TESTER) > 0)
      TesterStop();
    return false;
  }
  return true;
}

bool HedgedResolveAlligatorState(const SignalTypes direction,
                                 HedgedAlligatorState &state_out)
{
  state_out = HedgedAlligatorState();
  if(Hedged_Trend_Mode != HEDGED_TREND_ALLIGATOR)
    return false;

  ENUM_TIMEFRAMES tf = ResolveHedgedPrimaryTimeframe();
  if(!HedgedEnsureAlligatorHandle(tf))
    return false;

  double jaws_buf[1], teeth_buf[1], lips_buf[1];
  int copied_jaws  = CopyBuffer(g_hedged_alligator_handle, 0, 0, 1, jaws_buf);
  int copied_teeth = CopyBuffer(g_hedged_alligator_handle, 1, 0, 1, teeth_buf);
  int copied_lips  = CopyBuffer(g_hedged_alligator_handle, 2, 0, 1, lips_buf);
  if(copied_jaws < 1 || copied_teeth < 1 || copied_lips < 1)
    return false;

  state_out.jaws = jaws_buf[0];
  state_out.teeth = teeth_buf[0];
  state_out.lips = lips_buf[0];
  state_out.tf = tf;
  state_out.valid = (state_out.jaws > 0.0 && state_out.teeth > 0.0 && state_out.lips > 0.0);
  if(!state_out.valid)
    return false;

  HedgedAlligatorTrendPhase phase = HEDGED_TREND_PHASE_UNKNOWN;
  SignalTypes trend_dir = NO_SIGNAL;
  if(state_out.lips > state_out.teeth && state_out.teeth > state_out.jaws)
  {
    phase = HEDGED_TREND_PHASE_FULL;
    trend_dir = BULLISH;
  }
  else if(state_out.lips < state_out.teeth && state_out.teeth < state_out.jaws)
  {
    phase = HEDGED_TREND_PHASE_FULL;
    trend_dir = BEARISH;
  }
  else if(state_out.lips >= state_out.jaws && state_out.teeth < state_out.jaws)
  {
    phase = HEDGED_TREND_PHASE_FULL_WEAK;
    trend_dir = BULLISH;
  }
  else if(state_out.lips <= state_out.jaws && state_out.teeth > state_out.jaws)
  {
    phase = HEDGED_TREND_PHASE_FULL_WEAK;
    trend_dir = BEARISH;
  }
  else if((state_out.lips > state_out.teeth && state_out.lips < state_out.jaws) ||
          (state_out.lips < state_out.teeth && state_out.lips > state_out.jaws))
  {
    phase = HEDGED_TREND_PHASE_MEDIUM;
    trend_dir = direction;
  }
  else if(state_out.lips <= state_out.teeth && state_out.teeth <= state_out.jaws)
  {
    phase = HEDGED_TREND_PHASE_WRONG;
    trend_dir = BULLISH;
  }
  else if(state_out.lips >= state_out.teeth && state_out.teeth >= state_out.jaws)
  {
    phase = HEDGED_TREND_PHASE_WRONG;
    trend_dir = BEARISH;
  }

  state_out.phase = phase;
  state_out.trend_direction = trend_dir;
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_HEDGED_ALLIGATOR_STATE_MQH_
