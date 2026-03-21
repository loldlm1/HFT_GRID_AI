//+------------------------------------------------------------------+
//|      microservices/indicators/extremum_statistics_calculator.mqh |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_EXTREMUM_STATISTICS_CALCULATOR_MQH_
#define _MICROSERVICES_INDICATORS_EXTREMUM_STATISTICS_CALCULATOR_MQH_

//+------------------------------------------------------------------+
//| Calculate internal fibonacci for single extremum                 |
//| Returns percentage from previous opposite extremum               |
//+------------------------------------------------------------------+
double CalculateExtremumIntern(
  OscillatorMarketStructure &current,
  OscillatorMarketStructure &previous_opposite,
  bool current_is_peak
) {
  double current_price = current_is_peak ? current.extremum_high : current.extremum_low;
  double reference_price = current_is_peak ? previous_opposite.extremum_low : previous_opposite.extremum_high;

  if(current_is_peak)
  {
    // Peak: calculate percentage from bottom to peak
    // Can be > 100% if extended beyond previous peak
    return GetFiboTrendPeakPercent(current_price, reference_price, current_price);
  }
  else
  {
    // Bottom: calculate percentage from peak to bottom
    // Can be > 100% if extended beyond previous bottom
    return GetFiboTrendBottomPercent(current_price, reference_price, current_price);
  }
}

//+------------------------------------------------------------------+
//| Count structures broken to reach current level                   |
//+------------------------------------------------------------------+
int CountStructuresBroken(
  OscillatorMarketStructure &extrema_array[],
  int current_index,
  int reference_index,
  bool is_peak
) {
  if(reference_index < 0) return 0;

  int broken_count = 0;
  double current_price = is_peak ? extrema_array[current_index].extremum_high : extrema_array[current_index].extremum_low;

  // Count same-type extrema BETWEEN current and reference that were broken
  for(int i = current_index + 1; i <= reference_index; i++)
  {
    if(extrema_array[i].is_peak == is_peak)
    {
      double compare_price = is_peak ? extrema_array[i].extremum_high : extrema_array[i].extremum_low;

      if(is_peak)
      {
        // For peaks: count intermediate peaks lower than current (broken through)
        if(current_price > compare_price) broken_count++;
      }
      else
      {
        // For bottoms: count intermediate bottoms higher than current (broken through)
        if(current_price < compare_price) broken_count++;
      }
    }
  }

  return broken_count;
}

//+------------------------------------------------------------------+
//| Calculate external fibonacci for single extremum                 |
//| Uses the same reference structure that INTERN identified          |
//+------------------------------------------------------------------+
void CalculateExtremumExtern(
  OscillatorMarketStructure &extrema_array[],
  int current_index,
  int prev_same_type_index,
  int prev_opposite_index,
  ExtremumStatistics &stats
) {
  if(prev_same_type_index < 0 || prev_opposite_index < 0) return;

  bool   is_peak       = extrema_array[current_index].is_peak;
  double current_price = is_peak ? extrema_array[current_index].extremum_high : extrema_array[current_index].extremum_low;
  int    array_size    = ArraySize(extrema_array);

  if(array_size <= 0) return;

  // Step 1: walk back to locate the actual same-type structure the breakout is interacting with.
  int    reference_index        = -1;
  int    last_broken_same_index = prev_same_type_index;

  for(int i = prev_same_type_index; i < array_size; i++)
  {
    if(extrema_array[i].is_peak != is_peak) continue;

    double candidate_price = is_peak ? extrema_array[i].extremum_high : extrema_array[i].extremum_low;

    if(is_peak)
    {
      if(current_price > candidate_price)
      {
        last_broken_same_index = i;
        continue;
      }
    }
    else
    {
      if(current_price < candidate_price)
      {
        last_broken_same_index = i;
        continue;
      }
    }

    reference_index = i;
    break;
  }

  if(reference_index < 0)
  {
    reference_index = last_broken_same_index;
  }

  // Step 2: locate the matching opposite extremum forming the historical swing.
  int partner_index = -1;

  if(is_peak)
  {
    double lowest_bottom = DBL_MAX;

    for(int i = reference_index - 1; i > current_index; --i)
    {
      if(extrema_array[i].is_peak) continue;

      double candidate_low = extrema_array[i].extremum_low;

      if(candidate_low < lowest_bottom)
      {
        lowest_bottom = candidate_low;
        partner_index = i;
      }
    }

    if(partner_index < 0 && prev_opposite_index > current_index && prev_opposite_index < reference_index)
    {
      partner_index = prev_opposite_index;
      lowest_bottom = extrema_array[partner_index].extremum_low;
    }

    if(partner_index >= 0)
    {
      stats.extern_oldest_high = extrema_array[reference_index].extremum_high;
      stats.extern_oldest_low  = extrema_array[partner_index].extremum_low;
    }
    else
    {
      double global_low = DBL_MAX;
      for(int i = 0; i < array_size; i++)
      {
        if(extrema_array[i].extremum_low < global_low)
          global_low = extrema_array[i].extremum_low;
      }

      stats.extern_oldest_high = extrema_array[reference_index].extremum_high;
      stats.extern_oldest_low  = global_low;
    }
  }
  else
  {
    double highest_peak = -DBL_MAX;

    for(int i = reference_index - 1; i > current_index; --i)
    {
      if(!extrema_array[i].is_peak) continue;

      double candidate_high = extrema_array[i].extremum_high;

      if(candidate_high > highest_peak)
      {
        highest_peak = candidate_high;
        partner_index = i;
      }
    }

    if(partner_index < 0 && prev_opposite_index > current_index && prev_opposite_index < reference_index)
    {
      partner_index = prev_opposite_index;
      highest_peak = extrema_array[partner_index].extremum_high;
    }

    if(partner_index >= 0)
    {
      stats.extern_oldest_low  = extrema_array[reference_index].extremum_low;
      stats.extern_oldest_high = extrema_array[partner_index].extremum_high;
    }
    else
    {
      double global_high = -DBL_MAX;
      for(int i = 0; i < array_size; i++)
      {
        if(extrema_array[i].extremum_high > global_high)
          global_high = extrema_array[i].extremum_high;
      }

      stats.extern_oldest_low  = extrema_array[reference_index].extremum_low;
      stats.extern_oldest_high = global_high;
    }
  }

  // Step 3: fibonacci level is computed later once the complete range context is applied.
  stats.extern_fibo_level = 0.0;

  // Count every intervening same-type structure broken en route to the reference level.
  stats.extern_structures_broken = CountStructuresBroken(
    extrema_array,
    current_index,
    reference_index,
    is_peak
  );
}

//+------------------------------------------------------------------+
//| Main calculator - populates entire stats array                   |
//+------------------------------------------------------------------+
void CalculateAllExtremumStatistics(
  OscillatorMarketStructure &extrema_array[],
  ExtremumStatistics &stats_array[]
) {
  int array_size = ArraySize(extrema_array);

  if(array_size < 2)
  {
    ArrayResize(stats_array, 0);
    return;
  }

  // First classify all structure types
  ClassifyAllStructureTypes(extrema_array, stats_array);

  // Calculate EXTREMUM_INTERN for each extremum
  // INTERN measures: from previous opposite extremum to current, relative to previous same-type extremum
  for(int i = 0; i < array_size; i++)
  {
    bool current_is_peak = extrema_array[i].is_peak;
    double current_price = current_is_peak ? extrema_array[i].extremum_high : extrema_array[i].extremum_low;

    // Reset per-iteration statistics
    stats_array[i].intern_reference_price   = 0.0;
    stats_array[i].intern_fibo_level        = 0.0;
    stats_array[i].intern_fibo_raw_level    = 0.0;
    stats_array[i].extern_fibo_raw_level    = 0.0;
    stats_array[i].intern_is_extension      = false;
    stats_array[i].extern_is_active         = false;
    stats_array[i].extern_oldest_high       = -DBL_MAX;
    stats_array[i].extern_oldest_low        = DBL_MAX;
    stats_array[i].extern_structures_broken = 0;

    // Find previous opposite extremum (immediately before current)
    int prev_opposite_index = -1;
    int prev_same_type_index = -1;

    for(int j = i + 1; j < array_size; j++)
    {
      if(extrema_array[j].is_peak != current_is_peak && prev_opposite_index == -1)
      {
        prev_opposite_index = j;
      }
      else if(extrema_array[j].is_peak == current_is_peak && prev_same_type_index == -1)
      {
        prev_same_type_index = j;
        if(prev_opposite_index >= 0)
          break; // Found both, can stop
      }
    }

    // Need at least previous opposite extremum to calculate INTERN
    if(prev_opposite_index >= 0)
    {
      double reference_price = current_is_peak ?
        extrema_array[prev_opposite_index].extremum_low :
        extrema_array[prev_opposite_index].extremum_high;

      stats_array[i].intern_reference_price = reference_price;

      double prev_same_type_price = current_price;
      if(prev_same_type_index >= 0)
      {
        prev_same_type_price = current_is_peak ?
          extrema_array[prev_same_type_index].extremum_high :
          extrema_array[prev_same_type_index].extremum_low;
      }

      double intern_raw_level = 100.0;

      if(current_is_peak)
      {
        // For Peak: measure from previous bottom (0%) to current peak
        if(prev_same_type_price > reference_price)
        {
          intern_raw_level = ((current_price - reference_price) / (prev_same_type_price - reference_price)) * 100.0;
        }
      }
      else
      {
        // For Bottom: measure from previous peak (0%) to current bottom
        if(reference_price > prev_same_type_price)
        {
          intern_raw_level = ((reference_price - current_price) / (reference_price - prev_same_type_price)) * 100.0;
        }
      }

      if(intern_raw_level < 0.0)
        intern_raw_level = 0.0;

      stats_array[i].intern_fibo_raw_level = intern_raw_level;

      // Snap to nearest DefaultFibonacciLevel and normalize
      double next_level = 0;
      stats_array[i].intern_fibo_level = GetPreciseEntryLevelDefault(intern_raw_level, next_level);

      // Check if extension (>100%)
      stats_array[i].intern_is_extension = (stats_array[i].intern_fibo_level > 100.0);

      bool has_reference_for_extern = (prev_same_type_index >= 0 && prev_opposite_index >= 0);
      bool intern_gte_100 = (stats_array[i].intern_fibo_level >= 100.0);

      double extern_raw_level = 0.0;
      bool   has_complete_range = false;

      // Calculate EXTERN using the same reference structure as INTERN
      if(has_reference_for_extern)
      {
        CalculateExtremumExtern(
          extrema_array,
          i,
          prev_same_type_index,
          prev_opposite_index,
          stats_array[i]
        );

        double range_high = stats_array[i].extern_oldest_high;
        double range_low  = stats_array[i].extern_oldest_low;

        if(range_high > range_low &&
           range_high != -DBL_MAX &&
           range_low  != DBL_MAX)
        {
          if(current_is_peak)
            extern_raw_level = GetFiboTrendPeakPercent(range_high, range_low, current_price);
          else
            extern_raw_level = GetFiboTrendBottomPercent(range_high, range_low, current_price);

          if(extern_raw_level < 0.0)
            extern_raw_level = 0.0;

          stats_array[i].extern_fibo_raw_level = extern_raw_level;

          double next_extern_level = 0.0;
          stats_array[i].extern_fibo_level = GetPreciseEntryLevelDefault(extern_raw_level, next_extern_level);
          has_complete_range = true;
        }
      }

      // EXTERN flagged active once the intern level completes a full retest or breakout
      stats_array[i].extern_is_active = (has_complete_range && intern_gte_100);

      if(!has_complete_range)
      {
        stats_array[i].extern_fibo_level = 0.0;
        stats_array[i].extern_fibo_raw_level = 0.0;
      }
    }
  }
}

#endif // _MICROSERVICES_INDICATORS_EXTREMUM_STATISTICS_CALCULATOR_MQH_
