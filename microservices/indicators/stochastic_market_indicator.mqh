//+------------------------------------------------------------------+
//|         microservices/indicators/stochastic_market_indicator.mqh|
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_STOCHASTIC_MARKET_INDICATOR_MQH_
#define _MICROSERVICES_INDICATORS_STOCHASTIC_MARKET_INDICATOR_MQH_

#include "../core/enums.mqh"
#include "../core/base_structures.mqh"
#include "extrema_detector.mqh"
#include "structure_classifier.mqh"
#include "fibonacci_calculator.mqh"
#include "extremum_statistics_calculator.mqh"

//+------------------------------------------------------------------+
//| Main structure for Stochastic Market Structure analysis          |
//| Aggregates extrema, structure types, and Fibonacci levels        |
//+------------------------------------------------------------------+
struct StochasticMarketStructure
{
  // INDICATOR INFO
  ENUM_TIMEFRAMES indicator_timeframe;
  int             indicator_period;

  // Tipos de las 6 sub-estructuras
  OscillatorStructureTypes first_structure_type;
  OscillatorStructureTypes second_structure_type;
  OscillatorStructureTypes third_structure_type;
  OscillatorStructureTypes fourth_structure_type;
  OscillatorStructureTypes fifth_structure_type;
  OscillatorStructureTypes six_structure_type;

  // Datos de la primera sub-estructura
  datetime first_structure_time;
  double   first_structure_price;
  datetime second_structure_time;
  double   second_structure_price;
  datetime third_structure_time;
  double   third_structure_price;
  datetime fourth_structure_time;
  double   fourth_structure_price;

  // Niveles de Fibonacci calculados
  double first_fibonacci_level;
  double second_fibonacci_level;
  double third_fibonacci_level;
  double fourth_fibonacci_level;

  // Secuencia completa de extremos detectados
  OscillatorMarketStructure os_market_structures[];

  // NEW: Dynamic configuration and statistics
  int extrema_depth_config;           // Configurable depth (default 13)
  ExtremumStatistics extremum_stats[]; // Dynamic statistics array

  // DEFAULT CONSTRUCTOR
  StochasticMarketStructure()
  {
    indicator_timeframe   = PERIOD_CURRENT;
    indicator_period      = 0;
    extrema_depth_config  = 13;
    first_structure_type  = OSCILLATOR_STRUCTURE_EQ;
    second_structure_type = OSCILLATOR_STRUCTURE_EQ;
    third_structure_type  = OSCILLATOR_STRUCTURE_EQ;
    fourth_structure_type = OSCILLATOR_STRUCTURE_EQ;
    fifth_structure_type  = OSCILLATOR_STRUCTURE_EQ;
    six_structure_type    = OSCILLATOR_STRUCTURE_EQ;

    first_structure_time   = 0;
    first_structure_price  = 0.0;
    second_structure_time  = 0;
    second_structure_price = 0.0;
    third_structure_time   = 0;
    third_structure_price  = 0.0;
    fourth_structure_time  = 0;
    fourth_structure_price = 0.0;

    first_fibonacci_level  = 0.0;
    second_fibonacci_level = 0.0;
    third_fibonacci_level  = 0.0;
    fourth_fibonacci_level = 0.0;
  }

  // COPY CONSTRUCTOR
  StochasticMarketStructure(const StochasticMarketStructure &other)
  {
    indicator_timeframe    = other.indicator_timeframe;
    indicator_period       = other.indicator_period;
    first_structure_type   = other.first_structure_type;
    second_structure_type  = other.second_structure_type;
    third_structure_type   = other.third_structure_type;
    fourth_structure_type  = other.fourth_structure_type;
    fifth_structure_type   = other.fifth_structure_type;
    six_structure_type     = other.six_structure_type;

    first_structure_time   = other.first_structure_time;
    first_structure_price  = other.first_structure_price;
    second_structure_time  = other.second_structure_time;
    second_structure_price = other.second_structure_price;
    third_structure_time   = other.third_structure_time;
    third_structure_price  = other.third_structure_price;
    fourth_structure_time  = other.fourth_structure_time;
    fourth_structure_price = other.fourth_structure_price;

    first_fibonacci_level  = other.first_fibonacci_level;
    second_fibonacci_level = other.second_fibonacci_level;
    third_fibonacci_level  = other.third_fibonacci_level;
    fourth_fibonacci_level = other.fourth_fibonacci_level;

    ArrayCopy(os_market_structures, other.os_market_structures);

    extrema_depth_config  = other.extrema_depth_config;
    ArrayCopy(extremum_stats, other.extremum_stats);
  }

  //+------------------------------------------------------------------+
  //| Initialize all market structure values from indicator            |
  //| Returns: true if successful, false otherwise                     |
  //+------------------------------------------------------------------+
  bool InitStochMarketStructureValues(
    IndicatorsHandleInfo &structure_stoch_indicator_handle
  ) {
    bool initial_is_bottom = false;
    bool initial_is_peak   = false;

    // STEP 1: Detect extrema from Stochastic Structure indicator
    if(!DetectMarketExtrema(
      structure_stoch_indicator_handle,
      os_market_structures,
      initial_is_bottom,
      initial_is_peak,
      indicator_timeframe,
      indicator_period
    )) {
      return false;
    }

    // STEP 2: Classify structure types and extract time/price data
    OscillatorStructureTypes structure_types[6];
    StructureTimePrice structure_data[4];

    ClassifyStructureTypes(
      os_market_structures,
      initial_is_bottom,
      initial_is_peak,
      structure_types,
      structure_data
    );

    // Populate structure type fields
    first_structure_type  = structure_types[0];
    second_structure_type = structure_types[1];
    third_structure_type  = structure_types[2];
    fourth_structure_type = structure_types[3];
    fifth_structure_type  = structure_types[4];
    six_structure_type    = structure_types[5];

    // Populate structure time/price fields
    first_structure_time   = structure_data[0].structure_time;
    first_structure_price  = structure_data[0].structure_price;
    second_structure_time  = structure_data[1].structure_time;
    second_structure_price = structure_data[1].structure_price;
    third_structure_time   = structure_data[2].structure_time;
    third_structure_price  = structure_data[2].structure_price;
    fourth_structure_time  = structure_data[3].structure_time;
    fourth_structure_price = structure_data[3].structure_price;

    // STEP 3: Calculate Fibonacci levels
    double fibonacci_levels[4];

    CalculateFibonacciLevels(
      os_market_structures,
      initial_is_bottom,
      initial_is_peak,
      fibonacci_levels
    );

    // Populate Fibonacci level fields
    first_fibonacci_level  = fibonacci_levels[0];
    second_fibonacci_level = fibonacci_levels[1];
    third_fibonacci_level  = fibonacci_levels[2];
    fourth_fibonacci_level = fibonacci_levels[3];

    // STEP 4: Calculate extremum statistics (NEW)
    CalculateAllExtremumStatistics(
      os_market_structures,
      extremum_stats
    );

    return true;
  }

  //+------------------------------------------------------------------+
  //| NEW: Initialize with custom depth configuration                  |
  //| Allows configuring number of extrema to analyze                  |
  //+------------------------------------------------------------------+
  bool InitWithCustomDepth(
    IndicatorsHandleInfo &structure_stoch_indicator_handle,
    int custom_depth = 13
  ) {
    extrema_depth_config = custom_depth;

    bool initial_is_bottom = false;
    bool initial_is_peak   = false;

    // STEP 1: Detect extrema with custom depth
    if(!DetectMarketExtrema(
      structure_stoch_indicator_handle,
      os_market_structures,
      initial_is_bottom,
      initial_is_peak,
      indicator_timeframe,
      indicator_period,
      custom_depth  // Use custom depth
    )) {
      return false;
    }

    // STEP 2: Classify structure types and extract time/price data
    OscillatorStructureTypes structure_types[6];
    StructureTimePrice structure_data[4];

    ClassifyStructureTypes(
      os_market_structures,
      initial_is_bottom,
      initial_is_peak,
      structure_types,
      structure_data
    );

    // Populate structure type fields (backward compatibility)
    first_structure_type  = structure_types[0];
    second_structure_type = structure_types[1];
    third_structure_type  = structure_types[2];
    fourth_structure_type = structure_types[3];
    fifth_structure_type  = structure_types[4];
    six_structure_type    = structure_types[5];

    // Populate structure time/price fields (backward compatibility)
    first_structure_time   = structure_data[0].structure_time;
    first_structure_price  = structure_data[0].structure_price;
    second_structure_time  = structure_data[1].structure_time;
    second_structure_price = structure_data[1].structure_price;
    third_structure_time   = structure_data[2].structure_time;
    third_structure_price  = structure_data[2].structure_price;
    fourth_structure_time  = structure_data[3].structure_time;
    fourth_structure_price = structure_data[3].structure_price;

    // STEP 3: Calculate Fibonacci levels (backward compatibility)
    double fibonacci_levels[4];

    CalculateFibonacciLevels(
      os_market_structures,
      initial_is_bottom,
      initial_is_peak,
      fibonacci_levels
    );

    // Populate Fibonacci level fields
    first_fibonacci_level  = fibonacci_levels[0];
    second_fibonacci_level = fibonacci_levels[1];
    third_fibonacci_level  = fibonacci_levels[2];
    fourth_fibonacci_level = fibonacci_levels[3];

    // STEP 4: Calculate extremum statistics
    CalculateAllExtremumStatistics(
      os_market_structures,
      extremum_stats
    );

    return true;
  }
};

#endif // _MICROSERVICES_INDICATORS_STOCHASTIC_MARKET_INDICATOR_MQH_
