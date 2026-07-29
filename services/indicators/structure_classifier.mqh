//+------------------------------------------------------------------+
//|           microservices/indicators/structure_classifier.mqh      |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_STRUCTURE_CLASSIFIER_MQH_
#define _MICROSERVICES_INDICATORS_STRUCTURE_CLASSIFIER_MQH_

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

#endif // _MICROSERVICES_INDICATORS_STRUCTURE_CLASSIFIER_MQH_
