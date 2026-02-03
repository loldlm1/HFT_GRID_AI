//+------------------------------------------------------------------+
//|             trading_management/structure_fibonacci_levels.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_

#include "../utils/array_functions.mqh"

struct StructureFibonacciConfig
{
  double levels[];
  double last_step;
  bool   valid;

  StructureFibonacciConfig()
  {
    ArrayResize(levels, 0);
    last_step = 0.0;
    valid = false;
  }
};

bool ParseStructureFibonacciLevels(const string csv,
                                   double &levels_out[],
                                   string &error)
{
  ArrayResize(levels_out, 0);
  error = "";

  string parts[];
  int total = StringSplit(csv, ',', parts);
  if(total <= 0)
  {
    error = "empty levels";
    return false;
  }

  for(int i = 0; i < total; i++)
  {
    string token = parts[i];
    StringTrimLeft(token);
    StringTrimRight(token);
    if(token == "")
      continue;
    double value = StringToDouble(token);
    if(!MathIsValidNumber(value))
    {
      error = StringFormat("invalid level '%s'", token);
      return false;
    }
    AddElementToArray(levels_out, value);
  }

  if(ArraySize(levels_out) < 2)
  {
    error = "need at least 2 levels";
    return false;
  }

  ArraySort(levels_out);

  double deduped[];
  for(int i = 0; i < ArraySize(levels_out); i++)
  {
    double value = levels_out[i];
    if(ArraySize(deduped) == 0 || value > deduped[ArraySize(deduped) - 1])
      AddElementToArray(deduped, value);
  }

  if(ArraySize(deduped) < 2)
  {
    error = "levels must be strictly increasing";
    return false;
  }

  ArrayResize(levels_out, 0);
  ArrayCopy(levels_out, deduped);
  return true;
}

bool ResolveFibonacciRangeForPercent(const double &levels[],
                                     const int total,
                                     const double percent,
                                     double &lower_out,
                                     double &upper_out)
{
  lower_out = 0.0;
  upper_out = 0.0;
  if(total < 2)
    return false;

  if(percent < levels[0])
    return false;

  for(int i = 0; i < total - 1; i++)
  {
    double lower = levels[i];
    double upper = levels[i + 1];
    if(percent >= lower && percent < upper)
    {
      lower_out = lower;
      upper_out = upper;
      return true;
    }
  }

  double last = levels[total - 1];
  double step = last - levels[total - 2];
  if(step <= 0.0)
    return false;

  double upper = last;
  while(percent >= upper)
    upper += step;

  lower_out = upper - step;
  upper_out = upper;
  return true;
}

StructureFibonacciConfig g_structure_fibo_config;

bool LoadStructureFibonacciLevels(const string csv,
                                  const string fallback_csv)
{
  string error = "";
  double parsed[];
  if(!ParseStructureFibonacciLevels(csv, parsed, error))
  {
    if(!ParseStructureFibonacciLevels(fallback_csv, parsed, error))
      return false;
  }

  ArrayResize(g_structure_fibo_config.levels, 0);
  ArrayCopy(g_structure_fibo_config.levels, parsed);
  int total = ArraySize(g_structure_fibo_config.levels);
  g_structure_fibo_config.last_step = g_structure_fibo_config.levels[total - 1] -
                                      g_structure_fibo_config.levels[total - 2];
  g_structure_fibo_config.valid = (total >= 2 && g_structure_fibo_config.last_step > 0.0);
  return g_structure_fibo_config.valid;
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_
