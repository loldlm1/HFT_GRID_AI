//+------------------------------------------------------------------+
//|           microservices/indicators/fibonacci_calculator.mqh      |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_FIBONACCI_CALCULATOR_MQH_
#define _MICROSERVICES_INDICATORS_FIBONACCI_CALCULATOR_MQH_

double AllFibonacciLevels[101] = {
  0.0, 23.6, 38.2, 61.8, 78.6, 100.0,
  123.6, 138.2, 161.8, 178.6, 200.0,
  223.6, 238.2, 261.8, 278.6, 300.0,
  323.6, 338.2, 361.8, 378.6, 400.0,
  423.6, 438.2, 461.8, 478.6, 500.0,
  523.6, 538.2, 561.8, 578.6, 600.0,
  623.6, 638.2, 661.8, 678.6, 700.0,
  723.6, 738.2, 761.8, 778.6, 800.0,
  823.6, 838.2, 861.8, 878.6, 900.0,
  923.6, 938.2, 961.8, 978.6, 1000.0,
  1023.6, 1038.2, 1061.8, 1078.6, 1100.0,
  1123.6, 1138.2, 1161.8, 1178.6, 1200.0,
  1223.6, 1238.2, 1261.8, 1278.6, 1300.0,
  1323.6, 1338.2, 1361.8, 1378.6, 1400.0,
  1423.6, 1438.2, 1461.8, 1478.6, 1500.0,
  1523.6, 1538.2, 1561.8, 1578.6, 1600.0,
  1623.6, 1638.2, 1661.8, 1678.6, 1700.0,
  1723.6, 1738.2, 1761.8, 1778.6, 1800.0,
  1823.6, 1838.2, 1861.8, 1878.6, 1900.0,
  1923.6, 1938.2, 1961.8, 1978.6, 2000.0
};

double DefaultFibonacciLevels[9] = {
  0.0, 23.6, 38.2, 61.8, 78.6, 100.0,
  161.8, 261.8, 423.6
};

// Estructura de precios para niveles de Fibonacci
struct FibonacciLevelPrices
{
  double entry_level;       // precio del nivel de entrada calculado
  double entry_next_level;  // precio del siguiente nivel (para TP/gestión)

  // DEFAULT CONSTRUCTOR
  FibonacciLevelPrices()
  {
    entry_level      = 0.0;
    entry_next_level = 0.0;
  }

  // COPY CONSTRUCTOR
  FibonacciLevelPrices(const FibonacciLevelPrices &other)
  {
    entry_level      = other.entry_level;
    entry_next_level = other.entry_next_level;
  }
};

//+------------------------------------------------------------------+
//| LEVEL MAPPING: Find precise Fibonacci entry level               |
//| Uses AllFibonacciLevels for backward compatibility              |
//+------------------------------------------------------------------+
double GetPreciseEntryLevel(double entry_level, double &next_level)
{
  int    fibonacci_levels_total = ArraySize(AllFibonacciLevels)-1;
  double normalized_level       = NormalizeDouble(entry_level, 2);

  if(normalized_level <= AllFibonacciLevels[0])
  {
    next_level = AllFibonacciLevels[1];
    return AllFibonacciLevels[0];
  }

  for(int i = 0; i < fibonacci_levels_total; i++)
  {
    double lower = AllFibonacciLevels[i];
    double upper = AllFibonacciLevels[i+1];

    if(normalized_level >= lower && normalized_level < upper)
    {
      next_level = upper;
      return lower;
    }
  }

  next_level = AllFibonacciLevels[fibonacci_levels_total];
  return AllFibonacciLevels[fibonacci_levels_total];
}

//+------------------------------------------------------------------+
//| LEVEL MAPPING: Find precise Fibonacci entry level (Default Set) |
//| Uses DefaultFibonacciLevels for ExtremumStatistics              |
//+------------------------------------------------------------------+
double GetPreciseEntryLevelDefault(double entry_level, double &next_level)
{
  int    fibonacci_levels_total = ArraySize(DefaultFibonacciLevels)-1;
  double normalized_level       = NormalizeDouble(entry_level, 2);

  if(normalized_level <= DefaultFibonacciLevels[0])
  {
    next_level = DefaultFibonacciLevels[1];
    return DefaultFibonacciLevels[0];
  }

  for(int i = 0; i < fibonacci_levels_total; i++)
  {
    double lower = DefaultFibonacciLevels[i];
    double upper = DefaultFibonacciLevels[i+1];

    if(normalized_level >= lower && normalized_level < upper)
    {
      next_level = upper;
      return lower;
    }
  }

  next_level = DefaultFibonacciLevels[fibonacci_levels_total];
  return DefaultFibonacciLevels[fibonacci_levels_total];
}

//+------------------------------------------------------------------+
//| RETRACEMENT: Calculate Fibonacci retracement from bottom         |
//+------------------------------------------------------------------+
double GetFiboRetracementBottomPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = peak_price - ((percentage / 100.0) * diff_prices);

  return NormalizeDouble(percentage_price, _Digits);
}

//+------------------------------------------------------------------+
//| RETRACEMENT: Calculate Fibonacci retracement from peak           |
//+------------------------------------------------------------------+
double GetFiboRetracementPeakPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = bottom_price + ((percentage / 100.0) * diff_prices);

  return NormalizeDouble(percentage_price, _Digits);
}

//+------------------------------------------------------------------+
//| TREND: Calculate Fibonacci trend price from bottom               |
//+------------------------------------------------------------------+
double GetFiboTrendBottomPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = peak_price - ((percentage / 100.0) * diff_prices); // 0% IS THE PEAK

  return NormalizeDouble(percentage_price, _Digits);
}

//+------------------------------------------------------------------+
//| TREND: Calculate Fibonacci trend price from peak                 |
//+------------------------------------------------------------------+
double GetFiboTrendPeakPrice(double peak_price, double bottom_price, double percentage)
{
  double diff_prices      = peak_price - bottom_price;
  double percentage_price = ((percentage / 100.0) * diff_prices) + bottom_price; // 0% IS THE BOTTOM

  return NormalizeDouble(percentage_price, _Digits);
}

//+------------------------------------------------------------------+
//| TREND: Calculate Fibonacci trend percentage from peak            |
//+------------------------------------------------------------------+
double GetFiboTrendPeakPercent(double peak_price, double bottom_price, double price)
{
  double percentage = ((price - bottom_price) / (peak_price - bottom_price)) * 100.0; // 100% IS THE PEAK

  return NormalizeDouble(percentage, 1);
}

//+------------------------------------------------------------------+
//| TREND: Calculate Fibonacci trend percentage from bottom          |
//+------------------------------------------------------------------+
double GetFiboTrendBottomPercent(double peak_price, double bottom_price, double price)
{
  double percentage = ((peak_price - price) / (peak_price - bottom_price)) * 100.0; // 100% IS THE BOTTOM

  return NormalizeDouble(percentage, 1);
}

//+------------------------------------------------------------------+
//| EXPANSION: Calculate Fibonacci expansion price from bottom       |
//+------------------------------------------------------------------+
double GetFETrendBottomPrice(double peak_price, double bottom_price, double correction_peak_hh, double percentage)
{
  double diff_prices      = peak_price - bottom_price; // A -> B
  double percentage_price = correction_peak_hh - ((percentage / 100.0) * diff_prices); // SUBSTRACT (C) PEAK HH

  return NormalizeDouble(percentage_price, _Digits);
}

//+------------------------------------------------------------------+
//| EXPANSION: Calculate Fibonacci expansion price from peak         |
//+------------------------------------------------------------------+
double GetFETrendPeakPrice(double peak_price, double bottom_price, double correction_bottom_ll, double percentage)
{
  double diff_prices      = peak_price - bottom_price; // B -> A
  double percentage_price = correction_bottom_ll + ((percentage / 100.0) * diff_prices); // PLUS (C) BOTTOM LL

  return NormalizeDouble(percentage_price, _Digits);
}

//+------------------------------------------------------------------+
//| EXPANSION: Calculate Fibonacci expansion percentage from bottom  |
//+------------------------------------------------------------------+
double GetFETrendBottomPercentage(double peak_price, double bottom_price, double correction_peak_hh, double price)
{
  double diff_prices = peak_price - bottom_price;  // Movimiento A -> B
  double percentage  = ((correction_peak_hh - price) / diff_prices) * 100.0; // PEAK PRICE (C) IS 0%

  return NormalizeDouble(percentage, 1);
}

//+------------------------------------------------------------------+
//| EXPANSION: Calculate Fibonacci expansion percentage from peak    |
//+------------------------------------------------------------------+
double GetFETrendPeakPercentage(double peak_price, double bottom_price, double correction_bottom_ll, double price)
{
  double diff_prices = peak_price - bottom_price;  // Movimiento B -> A
  double percentage  = ((price - correction_bottom_ll) / diff_prices) * 100.0; // BOTTOM PRICE (C) IS 0%

  return NormalizeDouble(percentage, 1);
}

//+------------------------------------------------------------------+
//| HELPER: Calculate bullish Fibonacci percentage and level         |
//| Pattern: FIRST LOW -> FIRST HIGH -> SECOND LOW                   |
//+------------------------------------------------------------------+
double GetBullishFibonacciPercentage(double signal_entry_bottom_price, double signal_peak_price, double signal_bottom_price, bool raw_percent = false)
{
  FibonacciLevelPrices fibonacci_prices;
  double fibonacci_percentage = GetFiboTrendBottomPercent(signal_peak_price, signal_bottom_price, signal_entry_bottom_price);

  double next_level = 0;
  fibonacci_prices.entry_level      = raw_percent ? fibonacci_percentage : GetPreciseEntryLevel(fibonacci_percentage, next_level);
  fibonacci_prices.entry_next_level = next_level;

  return fibonacci_prices.entry_level;
}

//+------------------------------------------------------------------+
//| HELPER: Calculate bearish Fibonacci percentage and level         |
//| Pattern: FIRST HIGH -> FIRST LOW -> SECOND HIGH                  |
//+------------------------------------------------------------------+
double GetBearishFibonacciPercentage(double signal_entry_peak_price, double signal_bottom_price, double signal_peak_price, bool raw_percent = false)
{
  FibonacciLevelPrices fibonacci_prices;
  double fibonacci_percentage = GetFiboTrendPeakPercent(signal_peak_price, signal_bottom_price, signal_entry_peak_price);

  double next_level = 0;
  fibonacci_prices.entry_level      = raw_percent ? fibonacci_percentage : GetPreciseEntryLevel(fibonacci_percentage, next_level);
  fibonacci_prices.entry_next_level = next_level;

  return fibonacci_prices.entry_level;
}

//+------------------------------------------------------------------+
//| Calculate all 4 Fibonacci levels from extrema array              |
//+------------------------------------------------------------------+
void CalculateFibonacciLevels(
  ENUM_TIMEFRAMES indicator_timeframe,
  const OscillatorMarketStructure &extrema[],
  bool initial_is_bottom,
  bool initial_is_peak,
  double &fibonacci_levels[]
) {
  ArrayResize(fibonacci_levels, 4);

  // índices base para cálculos
  int structure_peaks_index   = initial_is_bottom ? 1 : 0;
  int structure_bottoms_index = initial_is_peak   ? 1 : 0;

  // FIBONACCI LEVELS
  if(initial_is_bottom)
  {
    fibonacci_levels[0] = GetBullishFibonacciPercentage(extrema[structure_bottoms_index].extremum_low,    extrema[structure_bottoms_index+1].extremum_high, extrema[structure_bottoms_index+2].extremum_low);
    fibonacci_levels[1] = GetBearishFibonacciPercentage(extrema[structure_bottoms_index+1].extremum_high, extrema[structure_bottoms_index+2].extremum_low,  extrema[structure_bottoms_index+3].extremum_high);
    fibonacci_levels[2] = GetBullishFibonacciPercentage(extrema[structure_bottoms_index+2].extremum_low,  extrema[structure_bottoms_index+3].extremum_high, extrema[structure_bottoms_index+4].extremum_low);
    fibonacci_levels[3] = GetBearishFibonacciPercentage(extrema[structure_bottoms_index+3].extremum_high, extrema[structure_bottoms_index+4].extremum_low,  extrema[structure_bottoms_index+5].extremum_high);
    // LIVE CLOSE PERCENT
    fibonacci_levels[4] = GetBullishFibonacciPercentage(iClose(_Symbol, indicator_timeframe, 0),    extrema[structure_bottoms_index+1].extremum_high, extrema[structure_bottoms_index+2].extremum_low, true);
  }

  if(initial_is_peak)
  {
    fibonacci_levels[0] = GetBearishFibonacciPercentage(extrema[structure_peaks_index].extremum_high,    extrema[structure_peaks_index+1].extremum_low,  extrema[structure_peaks_index+2].extremum_high);
    fibonacci_levels[1] = GetBullishFibonacciPercentage(extrema[structure_peaks_index+1].extremum_low,   extrema[structure_peaks_index+2].extremum_high, extrema[structure_peaks_index+3].extremum_low);
    fibonacci_levels[2] = GetBearishFibonacciPercentage(extrema[structure_peaks_index+2].extremum_high,  extrema[structure_peaks_index+3].extremum_low,  extrema[structure_peaks_index+4].extremum_high);
    fibonacci_levels[3] = GetBullishFibonacciPercentage(extrema[structure_peaks_index+3].extremum_low,   extrema[structure_peaks_index+4].extremum_high, extrema[structure_peaks_index+5].extremum_low);
    // LIVE CLOSE PERCENT
    fibonacci_levels[4] = GetBearishFibonacciPercentage(iClose(_Symbol, indicator_timeframe, 0),    extrema[structure_peaks_index+1].extremum_low,  extrema[structure_peaks_index+2].extremum_high, true);
  }
}

#endif // _MICROSERVICES_INDICATORS_FIBONACCI_CALCULATOR_MQH_
