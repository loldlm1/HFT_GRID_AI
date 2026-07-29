//+------------------------------------------------------------------+
//|                            indicators/pivot_points_calculator   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_INDICATORS_PIVOT_POINTS_CALCULATOR_MQH_
#define _SERVICES_INDICATORS_PIVOT_POINTS_CALCULATOR_MQH_

struct PivotPriceLadder
{
  bool   valid;
  double source_high;
  double source_low;
  double source_close;
  double source_range;
  double raw_prices[PIVOT_LEVEL_COUNT];
  double trade_prices[PIVOT_LEVEL_COUNT];

  PivotPriceLadder()
  {
    Reset();
  }

  PivotPriceLadder(const PivotPriceLadder &other)
  {
    CopyFrom(other);
  }

  void Reset()
  {
    valid        = false;
    source_high  = 0.0;
    source_low   = 0.0;
    source_close = 0.0;
    source_range = 0.0;
    for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    {
      raw_prices[i]   = 0.0;
      trade_prices[i] = 0.0;
    }
  }

  void CopyFrom(const PivotPriceLadder &other)
  {
    valid        = other.valid;
    source_high  = other.source_high;
    source_low   = other.source_low;
    source_close = other.source_close;
    source_range = other.source_range;
    for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
    {
      raw_prices[i]   = other.raw_prices[i];
      trade_prices[i] = other.trade_prices[i];
    }
  }
};

bool PivotSourceCandleValid(const MqlRates &source_rate,
                            string &reason_out)
{
  reason_out = "";

  if(source_rate.time <= 0)
  {
    reason_out = "INVALID_SOURCE_TIME";
    return false;
  }
  if(!MathIsValidNumber(source_rate.high) ||
     !MathIsValidNumber(source_rate.low) ||
     !MathIsValidNumber(source_rate.close))
  {
    reason_out = "INVALID_SOURCE_NUMBER";
    return false;
  }
  if(source_rate.low <= 0.0 || source_rate.high <= source_rate.low)
  {
    reason_out = "INVALID_SOURCE_RANGE";
    return false;
  }
  if(source_rate.close < source_rate.low || source_rate.close > source_rate.high)
  {
    reason_out = "SOURCE_CLOSE_OUTSIDE_RANGE";
    return false;
  }
  return true;
}

bool NormalizePivotTradePrice(const string symbol,
                              const double raw_price,
                              double &normalized_out)
{
  normalized_out = 0.0;
  if(symbol == "" || !MathIsValidNumber(raw_price) || raw_price <= 0.0)
    return false;

  double tick_size = 0.0;
  long digits_long = 0;
  if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tick_size) ||
     !SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits_long) ||
     tick_size <= 0.0 || digits_long < 0)
    return false;

  double tick_steps = MathRound(raw_price / tick_size);
  normalized_out = NormalizeDouble(tick_steps * tick_size, (int)digits_long);
  return MathIsValidNumber(normalized_out) && normalized_out > 0.0;
}

bool PivotTradeLadderStrictlyOrdered(const PivotPriceLadder &levels)
{
  for(int i = 1; i < PIVOT_LEVEL_COUNT; i++)
  {
    if(levels.trade_prices[i] <= levels.trade_prices[i - 1])
      return false;
  }
  return true;
}

bool BuildClassicPivotPriceLadder(const string symbol,
                                  const MqlRates &source_rate,
                                  PivotPriceLadder &levels_out,
                                  string &reason_out)
{
  levels_out.Reset();
  reason_out = "";

  if(!PivotSourceCandleValid(source_rate, reason_out))
    return false;

  double high  = source_rate.high;
  double low   = source_rate.low;
  double close = source_rate.close;
  double range = high - low;
  double pp    = (high + low + close) / 3.0;

  levels_out.source_high  = high;
  levels_out.source_low   = low;
  levels_out.source_close = close;
  levels_out.source_range = range;

  levels_out.raw_prices[PIVOT_LEVEL_PP] = pp;
  levels_out.raw_prices[PIVOT_LEVEL_R1] = 2.0 * pp - low;
  levels_out.raw_prices[PIVOT_LEVEL_S1] = 2.0 * pp - high;
  levels_out.raw_prices[PIVOT_LEVEL_R2] = pp + range;
  levels_out.raw_prices[PIVOT_LEVEL_S2] = pp - range;
  levels_out.raw_prices[PIVOT_LEVEL_R3] = high + 2.0 * (pp - low);
  levels_out.raw_prices[PIVOT_LEVEL_S3] = low - 2.0 * (high - pp);

  for(int i = 0; i < PIVOT_LEVEL_COUNT; i++)
  {
    if(!NormalizePivotTradePrice(symbol,
                                 levels_out.raw_prices[i],
                                 levels_out.trade_prices[i]))
    {
      reason_out = "PRICE_NORMALIZATION_FAILED_" + IntegerToString(i);
      levels_out.Reset();
      return false;
    }
  }

  if(!PivotTradeLadderStrictlyOrdered(levels_out))
  {
    reason_out = "NORMALIZED_LEVELS_NOT_STRICTLY_ORDERED";
    levels_out.Reset();
    return false;
  }

  levels_out.valid = true;
  return true;
}

bool PivotTradePrice(const PivotPriceLadder &levels,
                     const PivotLevelIds level,
                     double &price_out)
{
  price_out = 0.0;
  int index = (int)level;
  if(!levels.valid || index < 0 || index >= PIVOT_LEVEL_COUNT)
    return false;
  price_out = levels.trade_prices[index];
  return MathIsValidNumber(price_out) && price_out > 0.0;
}

#endif // _SERVICES_INDICATORS_PIVOT_POINTS_CALCULATOR_MQH_
