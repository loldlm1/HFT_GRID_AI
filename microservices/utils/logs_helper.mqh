//+------------------------------------------------------------------+
//|                          microservices/utils/logs_helper.mqh   |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_LOGS_HELPER_MQH_
#define _MICROSERVICES_UTILS_LOGS_HELPER_MQH_

#include "../core/enums.mqh"
#include "../indicators/structure_classifier.mqh"

// Forward declarations - these will be resolved when indicator structures are included
struct SignalParams;
struct BandsPercentStructure;
struct StochasticStructure;
struct StochasticMarketStructure;
struct BodyMAStructure;
struct ExtremumStatistics;
struct RetestZoneStatistics;
struct OscillatorMarketStructure;

// External globals that will be defined in the main EA or service layer
extern string g_dataset_id;

// ── Helpers ─────────────────────────────────────────────────────────────

void Log_Custom(string text)
{
  if(Enable_Logs) Print(text);
}

string TimeframeToString(const ENUM_TIMEFRAMES tf)
{
  switch (tf)
  {
    case PERIOD_M1:  return "M1";
    case PERIOD_M2:  return "M2";
    case PERIOD_M3:  return "M3";
    case PERIOD_M4:  return "M4";
    case PERIOD_M5:  return "M5";
    case PERIOD_M6:  return "M6";
    case PERIOD_M10: return "M10";
    case PERIOD_M12: return "M12";
    case PERIOD_M15: return "M15";
    case PERIOD_M20: return "M20";
    case PERIOD_M30: return "M30";
    case PERIOD_H1:  return "H1";
    case PERIOD_H2:  return "H2";
    case PERIOD_H3:  return "H3";
    case PERIOD_H4:  return "H4";
    case PERIOD_H6:  return "H6";
    case PERIOD_H8:  return "H8";
    case PERIOD_H12: return "H12";
    case PERIOD_D1:  return "D1";
    case PERIOD_W1:  return "W1";
    case PERIOD_MN1: return "MN1";
  }
  return StringFormat("TF(%d)", (int)tf);
}

string OscillatorStructureTypesToString(const OscillatorStructureTypes t)
{
  switch (t)
  {
    case OSCILLATOR_STRUCTURE_EQ: return "EQ";
    case OSCILLATOR_STRUCTURE_HH: return "HH";
    case OSCILLATOR_STRUCTURE_HL: return "HL";
    case OSCILLATOR_STRUCTURE_LH: return "LH";
    case OSCILLATOR_STRUCTURE_LL: return "LL";
  }
  return StringFormat("T(%d)", (int)t);
}

string SignalTypeToString(const SignalTypes s)
{
  switch (s)
  {
    case NO_SIGNAL: return "NO_SIGNAL";
    case BULLISH:   return "BULLISH";
    case BEARISH:   return "BEARISH";
  }
  return StringFormat("SIG(%d)", (int)s);
}

// Ajusta si tienes un enum de estados con etiquetas propias
string SignalStateToString(const SignalStates st)
{
  return StringFormat("STATE(%s)", EnumToString(st));
}

string BodyTrendTypeToString(const BodyTrendTypes t)
{
  switch (t)
  {
    case BODY_UNDEFINED:     return "BODY_UNDEFINED";
    case STRONG_BODY_TREND:  return "STRONG_BODY_TREND";
    case WEAK_BODY_TREND:    return "WEAK_BODY_TREND";
  }
  return StringFormat("BODY_TREND(%d)", (int)t);
}

string BodyMATypeToString(const BodyMATypes t)
{
  switch (t)
  {
    case BODY_UNDEFINED_MA: return "BODY_UNDEFINED_MA";
    case BODY_BULLISH_MA:   return "BODY_BULLISH_MA";
    case BODY_BEARISH_MA:   return "BODY_BEARISH_MA";
  }
  return StringFormat("BODY_MA(%d)", (int)t);
}

string DtToStr(const datetime t)
{
  return TimeToString(t, TIME_DATE | TIME_SECONDS);
}

// Default no-const: usamos -1 y caemos al dígito del símbolo
string P(const double v, const int digits = -1)
{
  int use_digits = digits;
  if (use_digits < 0)
    use_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  return DoubleToString(v, use_digits);
}

// ── Logger filtrado por timeframe ───────────────────────────────────────

// Snapshot logging removed with per-context indicator storage; left as stub for compatibility.
void LogSignalParamsForTF(const SignalParams &signal_params,
                          const ENUM_TIMEFRAMES timeframe,
                          const int max_slots = -1)
{
  // suppress unused warnings
  SignalTypes _dir = signal_params.signal_type;
  if(_dir == NO_SIGNAL && timeframe == PERIOD_CURRENT && max_slots < 0)
    return;
}

#endif // _MICROSERVICES_UTILS_LOGS_HELPER_MQH_
