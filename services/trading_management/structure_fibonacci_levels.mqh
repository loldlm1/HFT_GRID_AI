//+------------------------------------------------------------------+
//|             trading_management/structure_fibonacci_levels.mqh    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_
#define _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_

#include "../utils/array_functions.mqh"

struct StructureFibonacciConfig
{
  double levels[];
  double cycle_levels[];
  double last_step;
  bool   valid;
  bool   cycle_valid;
  bool   cycle_allow_zero;

  StructureFibonacciConfig()
  {
    ArrayResize(levels, 0);
    ArrayResize(cycle_levels, 0);
    last_step = 0.0;
    valid = false;
    cycle_valid = false;
    cycle_allow_zero = false;
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

bool HasLevelValue(const double &levels[],
                   const int total,
                   const double value)
{
  for(int i = 0; i < total; i++)
  {
    if(MathAbs(levels[i] - value) < 0.0001)
      return true;
  }
  return false;
}

bool BuildCycleLevels(const double &levels[],
                      const int total,
                      double &cycle_out[],
                      bool &allow_zero_out)
{
  ArrayResize(cycle_out, 0);
  allow_zero_out = false;
  if(total < 2)
    return false;

  double tmp[];
  ArrayCopy(tmp, levels);
  int tmp_total = ArraySize(tmp);
  bool has_zero = HasLevelValue(tmp, tmp_total, 0.0);
  bool has_hundred = HasLevelValue(tmp, tmp_total, 100.0);

  allow_zero_out = (has_zero || has_hundred);
  if(allow_zero_out)
  {
    if(!has_zero)
    {
      double zero_value = 0.0;
      AddElementToArray(tmp, zero_value);
    }
    if(!has_hundred)
    {
      double hundred_value = 100.0;
      AddElementToArray(tmp, hundred_value);
    }
  }

  ArraySort(tmp);

  double deduped[];
  for(int i = 0; i < ArraySize(tmp); i++)
  {
    double value = tmp[i];
    if(ArraySize(deduped) == 0 || value > deduped[ArraySize(deduped) - 1])
      AddElementToArray(deduped, value);
  }

  ArrayCopy(cycle_out, deduped);
  return (ArraySize(cycle_out) >= 2);
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

bool ResolveFibonacciRangeForPercentStrict(const double &levels[],
                                           const int total,
                                           const double percent,
                                           double &lower_out,
                                           double &upper_out)
{
  lower_out = 0.0;
  upper_out = 0.0;
  if(total < 2)
    return false;

  if(percent < levels[0] || percent > levels[total - 1])
    return false;

  for(int i = 0; i < total - 1; i++)
  {
    double lower = levels[i];
    double upper = levels[i + 1];
    if(percent >= lower && percent <= upper)
    {
      lower_out = lower;
      upper_out = upper;
      return true;
    }
  }

  return false;
}

bool ResolveFibonacciNextPercent(const double &levels[],
                                 const int total,
                                 const double percent,
                                 const int steps,
                                 double &next_out)
{
  next_out = 0.0;
  if(total < 2 || steps <= 0)
    return false;

  double cursor = percent;
  double lower = 0.0;
  double upper = 0.0;
  for(int i = 0; i < steps; i++)
  {
    if(!ResolveFibonacciRangeForPercent(levels, total, cursor, lower, upper))
      return false;
    cursor = upper;
  }

  next_out = cursor;
  return true;
}

bool ResolveFibonacciNextPercentCycledUp(const double &levels[],
                                         const int total,
                                         const double percent,
                                         double &next_out)
{
  if(total < 2)
    return false;

  double max_level = levels[total - 1];
  if(max_level <= 0.0)
    return false;

  double eps = 0.0001;
  if(percent < 0.0)
  {
    double abs_value = MathAbs(percent);
    if(abs_value <= levels[0] + eps)
    {
      next_out = 0.0;
      return true;
    }

    double prev = levels[0];
    for(int i = 1; i < total; i++)
    {
      if(levels[i] + eps >= abs_value)
        break;
      prev = levels[i];
    }

    next_out = -prev;
    return true;
  }

  double base = MathFloor(percent / max_level) * max_level;
  double cursor = percent - base;

  for(int i = 0; i < total; i++)
  {
    if(levels[i] - cursor > eps)
    {
      next_out = base + levels[i];
      return true;
    }
  }

  next_out = base + max_level + levels[0];
  return true;
}

bool ResolveFibonacciNextPercentCycledDown(const double &levels[],
                                           const int total,
                                           const double percent,
                                           double &next_out)
{
  if(total < 2)
    return false;

  double max_level = levels[total - 1];
  if(max_level <= 0.0)
    return false;

  double eps = 0.0001;
  if(percent <= 0.0)
  {
    double abs_value = MathAbs(percent);
    if(abs_value < eps)
    {
      int nearest_negative = -1;
      for(int i = total - 1; i >= 0; i--)
      {
        if(levels[i] < -eps)
        {
          nearest_negative = i;
          break;
        }
      }
      if(nearest_negative >= 0)
      {
        next_out = levels[nearest_negative];
        return true;
      }

      int first_positive = 0;
      while(first_positive < total && levels[first_positive] <= 0.0)
        first_positive++;
      if(first_positive >= total)
        return false;
      next_out = -levels[first_positive];
      return true;
    }

    double base = MathFloor(abs_value / max_level) * max_level;
    double cursor = abs_value - base;
    if(cursor < eps)
    {
      // At exact negative cycle boundaries (e.g. -100 with 0,61.8,100),
      // advance to the next deeper negative node instead of repeating itself.
      if(levels[0] >= -eps)
      {
        int first_positive = 0;
        while(first_positive < total && levels[first_positive] <= eps)
          first_positive++;
        if(first_positive < total)
        {
          next_out = -(base + levels[first_positive]);
          return true;
        }
      }

      next_out = -(base + levels[0]);
      return true;
    }

    for(int i = 0; i < total; i++)
    {
      if(levels[i] - cursor > eps)
      {
        next_out = -(base + levels[i]);
        return true;
      }
    }

    next_out = -(base + max_level + levels[0]);
    return true;
  }

  double base = MathFloor(percent / max_level) * max_level;
  double cursor = percent - base;
  if(cursor < eps)
  {
    base -= max_level;
    cursor = max_level;
  }

  if(cursor <= levels[0] + eps)
  {
    next_out = base;
    return true;
  }

  double prev = levels[0];
  for(int i = 1; i < total; i++)
  {
    if(levels[i] + eps >= cursor)
      break;
    prev = levels[i];
  }

  next_out = base + prev;
  return true;
}

bool ResolveFibonacciNextPercentCycledWithCycle(const double &cycle_levels[],
                                                const int total,
                                                const bool allow_zero,
                                                const double percent,
                                                const int steps,
                                                const int direction,
                                                double &next_out)
{
  next_out = 0.0;
  if(total < 2 || steps <= 0)
    return false;

  int step_dir = (direction < 0) ? -1 : 1;
  double eps = 0.0001;
  double cursor = percent;
  for(int i = 0; i < steps; i++)
  {
    if(step_dir > 0)
    {
      if(!ResolveFibonacciNextPercentCycledUp(cycle_levels, total, cursor, cursor))
        return false;
    }
    else
    {
      if(!ResolveFibonacciNextPercentCycledDown(cycle_levels, total, cursor, cursor))
        return false;
    }

    if(!allow_zero && MathAbs(cursor) < eps)
    {
      if(step_dir > 0)
      {
        if(!ResolveFibonacciNextPercentCycledUp(cycle_levels, total, cursor, cursor))
          return false;
      }
      else
      {
        if(!ResolveFibonacciNextPercentCycledDown(cycle_levels, total, cursor, cursor))
          return false;
      }
    }
  }

  next_out = cursor;
  return true;
}

bool ResolveFibonacciNextPercentCycled(const double &levels[],
                                       const int total,
                                       const double percent,
                                       const int steps,
                                       const int direction,
                                       double &next_out)
{
  next_out = 0.0;
  double cycle_levels[];
  bool allow_zero = false;
  if(!BuildCycleLevels(levels, total, cycle_levels, allow_zero))
    return false;

  return ResolveFibonacciNextPercentCycledWithCycle(cycle_levels,
                                                    ArraySize(cycle_levels),
                                                    allow_zero,
                                                    percent,
                                                    steps,
                                                    direction,
                                                    next_out);
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
  g_structure_fibo_config.cycle_valid = BuildCycleLevels(g_structure_fibo_config.levels,
                                                         total,
                                                         g_structure_fibo_config.cycle_levels,
                                                         g_structure_fibo_config.cycle_allow_zero);
  return (g_structure_fibo_config.valid && g_structure_fibo_config.cycle_valid);
}

#endif // _SERVICES_TRADING_MANAGEMENT_STRUCTURE_FIBONACCI_LEVELS_MQH_
