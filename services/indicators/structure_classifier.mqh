//+------------------------------------------------------------------+
//|           microservices/indicators/structure_classifier.mqh      |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_STRUCTURE_CLASSIFIER_MQH_
#define _MICROSERVICES_INDICATORS_STRUCTURE_CLASSIFIER_MQH_

#include "extrema_detector.mqh"

// Helper structure to hold time/price pairs for structures
struct StructureTimePrice
{
  datetime structure_time;
  double   structure_price;

  StructureTimePrice()
  {
    structure_time  = 0;
    structure_price = 0.0;
  }
};

// Advanced extremum statistics structure
struct ExtremumStatistics
{
  int      extremum_index;           // Position in array (0 = most recent)

  // EXTREMUM_INTERN
  double   intern_fibo_level;        // Fib % from previous opposite extremum
  double   intern_reference_price;   // The reference price used
  bool     intern_is_extension;      // True if > 100%
  double   intern_fibo_raw_level;    // Raw fib % prior to snapping

  // EXTREMUM_EXTERN
  double   extern_fibo_raw_level;    // Raw fib % prior to snapping
  double   extern_fibo_level;        // Fib % from oldest extremum range
  double   extern_oldest_high;       // Oldest peak reference
  double   extern_oldest_low;        // Oldest bottom reference
  int      extern_structures_broken; // Count of highs/lows exceeded
  bool     extern_is_active;         // True when intern >= 100%

  // Structure classification
  OscillatorStructureTypes structure_type; // HH, HL, LL, LH, EQ

  // DEFAULT CONSTRUCTOR
  ExtremumStatistics()
  {
    extremum_index           = -1;
    intern_fibo_level        = 0.0;
    intern_reference_price   = 0.0;
    intern_is_extension      = false;
    intern_fibo_raw_level    = 0.0;
    extern_fibo_raw_level    = 0.0;
    extern_fibo_level        = 0.0;
    extern_oldest_high       = -DBL_MAX;
    extern_oldest_low        = DBL_MAX;
    extern_structures_broken = 0;
    extern_is_active         = false;
    structure_type           = OSCILLATOR_STRUCTURE_EQ;
  }

  // COPY CONSTRUCTOR
  ExtremumStatistics(const ExtremumStatistics &other)
  {
    extremum_index           = other.extremum_index;
    intern_fibo_level        = other.intern_fibo_level;
    intern_reference_price   = other.intern_reference_price;
    intern_is_extension      = other.intern_is_extension;
    intern_fibo_raw_level    = other.intern_fibo_raw_level;
    extern_fibo_raw_level    = other.extern_fibo_raw_level;
    extern_fibo_level        = other.extern_fibo_level;
    extern_oldest_high       = other.extern_oldest_high;
    extern_oldest_low        = other.extern_oldest_low;
    extern_structures_broken = other.extern_structures_broken;
    extern_is_active         = other.extern_is_active;
    structure_type           = other.structure_type;
  }
};

//+------------------------------------------------------------------+
//| Determine structure type (HH, LH, HL, LL, EQ)                    |
//+------------------------------------------------------------------+
OscillatorStructureTypes GetOscillatorStructureType(
  OscillatorPricesTypes price_type,
  double main_price,
  double past_price
) {
  if(
    price_type == OSCILLATOR_HIGH_PRICES &&
    main_price > past_price
  ) return OSCILLATOR_STRUCTURE_HH;

  if(
    price_type == OSCILLATOR_HIGH_PRICES &&
    main_price < past_price
  ) return OSCILLATOR_STRUCTURE_LH;

  if(
    price_type == OSCILLATOR_LOW_PRICES &&
    main_price > past_price
  ) return OSCILLATOR_STRUCTURE_HL;

  if(
    price_type == OSCILLATOR_LOW_PRICES &&
    main_price < past_price
  ) return OSCILLATOR_STRUCTURE_LL;

  return OSCILLATOR_STRUCTURE_EQ;
}

//+------------------------------------------------------------------+
//| Classify structure types from extrema array                      |
//+------------------------------------------------------------------+
void ClassifyStructureTypes(
  OscillatorMarketStructure &extrema[],
  bool initial_is_bottom,
  bool initial_is_peak,
  OscillatorStructureTypes &structure_types[],
  StructureTimePrice &structure_data[]
) {
  // Ensure arrays are properly sized
  ArrayResize(structure_types, 6);
  ArrayResize(structure_data, 4);

  // Initialize to defaults
  for(int i = 0; i < 6; i++)
    structure_types[i] = OSCILLATOR_STRUCTURE_EQ;

  // índices base para cálculos
  int structure_peaks_index   = initial_is_bottom ? 1 : 0;
  int structure_bottoms_index = initial_is_peak   ? 1 : 0;

  // tipos de estructura + datos individuales
  if(initial_is_bottom)
  {
    structure_types[0] = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  extrema[structure_bottoms_index].extremum_low,      extrema[structure_bottoms_index+2].extremum_low);
    structure_types[1] = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, extrema[structure_peaks_index].extremum_high,       extrema[structure_peaks_index+2].extremum_high);
    structure_types[2] = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  extrema[structure_bottoms_index+2].extremum_low,    extrema[structure_bottoms_index+4].extremum_low);
    structure_types[3] = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, extrema[structure_peaks_index+2].extremum_high,     extrema[structure_peaks_index+4].extremum_high);
    structure_types[4] = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  extrema[structure_bottoms_index+4].extremum_low,    extrema[structure_bottoms_index+6].extremum_low);
    structure_types[5] = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, extrema[structure_peaks_index+4].extremum_high,     extrema[structure_peaks_index+6].extremum_high);

    // EXTREMUM STATS
    structure_data[0].structure_time  = extrema[structure_bottoms_index].extremum_time;
    structure_data[0].structure_price = extrema[structure_bottoms_index].extremum_low;
    structure_data[1].structure_time  = extrema[structure_bottoms_index+1].extremum_time;
    structure_data[1].structure_price = extrema[structure_bottoms_index+1].extremum_high;
    structure_data[2].structure_time  = extrema[structure_bottoms_index+2].extremum_time;
    structure_data[2].structure_price = extrema[structure_bottoms_index+2].extremum_low;
    structure_data[3].structure_time  = extrema[structure_bottoms_index+3].extremum_time;
    structure_data[3].structure_price = extrema[structure_bottoms_index+3].extremum_high;
  }

  if(initial_is_peak)
  {
    structure_types[0] = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, extrema[structure_peaks_index].extremum_high,       extrema[structure_peaks_index+2].extremum_high);
    structure_types[1] = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  extrema[structure_bottoms_index].extremum_low,      extrema[structure_bottoms_index+2].extremum_low);
    structure_types[2] = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, extrema[structure_peaks_index+2].extremum_high,     extrema[structure_peaks_index+4].extremum_high);
    structure_types[3] = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  extrema[structure_bottoms_index+2].extremum_low,    extrema[structure_bottoms_index+4].extremum_low);
    structure_types[4] = GetOscillatorStructureType(OSCILLATOR_HIGH_PRICES, extrema[structure_peaks_index+4].extremum_high,     extrema[structure_peaks_index+6].extremum_high);
    structure_types[5] = GetOscillatorStructureType(OSCILLATOR_LOW_PRICES,  extrema[structure_bottoms_index+4].extremum_low,    extrema[structure_bottoms_index+6].extremum_low);

    // EXTREMUM STATS
    structure_data[0].structure_time  = extrema[structure_peaks_index].extremum_time;
    structure_data[0].structure_price = extrema[structure_peaks_index].extremum_high;
    structure_data[1].structure_time  = extrema[structure_peaks_index+1].extremum_time;
    structure_data[1].structure_price = extrema[structure_peaks_index+1].extremum_low;
    structure_data[2].structure_time  = extrema[structure_peaks_index+2].extremum_time;
    structure_data[2].structure_price = extrema[structure_peaks_index+2].extremum_high;
    structure_data[3].structure_time  = extrema[structure_peaks_index+3].extremum_time;
    structure_data[3].structure_price = extrema[structure_peaks_index+3].extremum_low;
  }
}

//+------------------------------------------------------------------+
//| Calculate structure types for all extrema dynamically            |
//+------------------------------------------------------------------+
void ClassifyAllStructureTypes(
  OscillatorMarketStructure &extrema_array[],
  ExtremumStatistics &stats_array[]
) {
  int array_size = ArraySize(extrema_array);
  ArrayResize(stats_array, array_size);

  // Initialize all stats with extremum index
  for(int i = 0; i < array_size; i++)
  {
    stats_array[i].extremum_index = i;
  }

  // Calculate structure types by comparing each extremum with the one 2 positions ahead
  for(int i = 0; i < array_size - 2; i++)
  {
    bool is_peak = extrema_array[i].is_peak;

    if(is_peak)
    {
      // Compare peak with next peak (2 positions ahead)
      double current_high = extrema_array[i].extremum_high;
      double next_high    = extrema_array[i+2].extremum_high;
      stats_array[i].structure_type = GetOscillatorStructureType(
        OSCILLATOR_HIGH_PRICES,
        current_high,
        next_high
      );
    }
    else
    {
      // Compare bottom with next bottom (2 positions ahead)
      double current_low = extrema_array[i].extremum_low;
      double next_low    = extrema_array[i+2].extremum_low;
      stats_array[i].structure_type = GetOscillatorStructureType(
        OSCILLATOR_LOW_PRICES,
        current_low,
        next_low
      );
    }
  }

  // Last 2 extrema don't have a comparison point, leave as EQ
  if(array_size >= 2)
  {
    stats_array[array_size-1].structure_type = OSCILLATOR_STRUCTURE_EQ;
    stats_array[array_size-2].structure_type = OSCILLATOR_STRUCTURE_EQ;
  }
}

#endif // _MICROSERVICES_INDICATORS_STRUCTURE_CLASSIFIER_MQH_
