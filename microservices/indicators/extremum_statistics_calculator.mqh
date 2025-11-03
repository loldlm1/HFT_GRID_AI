//+------------------------------------------------------------------+
//|      microservices/indicators/extremum_statistics_calculator.mqh |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_INDICATORS_EXTREMUM_STATISTICS_CALCULATOR_MQH_
#define _MICROSERVICES_INDICATORS_EXTREMUM_STATISTICS_CALCULATOR_MQH_

#include "extrema_detector.mqh"
#include "structure_classifier.mqh"
#include "fibonacci_calculator.mqh"

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
//| Helper: validate that EXTREN range context is usable             |
//+------------------------------------------------------------------+
bool HasValidRetestContext(double range_high, double range_low)
{
  if(range_high == -DBL_MAX || range_low == DBL_MAX)
    return false;
  return range_high > range_low;
}

//+------------------------------------------------------------------+
//| Helper: compare two context ranges with epsilon tolerance        |
//+------------------------------------------------------------------+
bool IsSameRetestContext(
  double first_high,
  double first_low,
  double second_high,
  double second_low,
  double epsilon
) {
  if(!HasValidRetestContext(first_high, first_low))
    return false;
  if(!HasValidRetestContext(second_high, second_low))
    return false;
  return MathAbs(first_high - second_high) <= epsilon &&
         MathAbs(first_low - second_low)   <= epsilon;
}

//+------------------------------------------------------------------+
//| Update cumulative support / resistance retest counters           |
//+------------------------------------------------------------------+
void UpdateRetestCounters(
  OscillatorMarketStructure &extrema_array[],
  ExtremumStatistics &stats_array[]
) {
  int array_size = ArraySize(extrema_array);
  int support_counter[FIBO_RETEST_ZONES_TOTAL];
  double support_context_high[FIBO_RETEST_ZONES_TOTAL];
  double support_context_low[FIBO_RETEST_ZONES_TOTAL];
  bool support_context_active[FIBO_RETEST_ZONES_TOTAL];

  int resistance_counter[FIBO_RETEST_ZONES_TOTAL];
  double resistance_context_high[FIBO_RETEST_ZONES_TOTAL];
  double resistance_context_low[FIBO_RETEST_ZONES_TOTAL];
  bool resistance_context_active[FIBO_RETEST_ZONES_TOTAL];

  double price_epsilon = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  if(price_epsilon <= 0.0)
    price_epsilon = 0.0001;

  for(int z = 0; z < FIBO_RETEST_ZONES_TOTAL; z++)
  {
    support_counter[z] = 0;
    support_context_high[z] = 0.0;
    support_context_low[z] = 0.0;
    support_context_active[z] = false;

    resistance_counter[z] = 0;
    resistance_context_high[z] = 0.0;
    resistance_context_low[z] = 0.0;
    resistance_context_active[z] = false;
  }

  // Single pass (oldest -> newest): manage support (bottoms) and resistance (peaks)
  for(int i = array_size - 1; i >= 0; --i)
  {
    bool is_peak = extrema_array[i].is_peak;
    for(int z = 0; z < FIBO_RETEST_ZONES_TOTAL; z++)
    {
      stats_array[i].fibo_retest_zones[z].support_retest_trigger = false;
      stats_array[i].fibo_retest_zones[z].resistance_retest_trigger = false;
      stats_array[i].fibo_retest_zones[z].support_retest_count = 0;
      stats_array[i].fibo_retest_zones[z].resistance_retest_count = 0;
    }

    for(int z = 0; z < FIBO_RETEST_ZONES_TOTAL; z++)
    {
      double zone_low = stats_array[i].fibo_retest_zones[z].zone_price_low;
      double zone_high = stats_array[i].fibo_retest_zones[z].zone_price_high;
      bool has_price_range = (zone_high > zone_low) && (zone_low != 0.0 || zone_high != 0.0);
      double extern_high = stats_array[i].extern_oldest_high;
      double extern_low  = stats_array[i].extern_oldest_low;
      bool context_valid = has_price_range && HasValidRetestContext(extern_high, extern_low);

      if(!context_valid)
      {
        if(is_peak)
        {
          resistance_context_active[z] = false;
          resistance_counter[z] = 0;
        }
        else
        {
          support_context_active[z] = false;
          support_counter[z] = 0;
        }
        continue;
      }

      bool zone_hit = stats_array[i].fibo_retest_zones[z].zone_hit;

      if(is_peak)
      {
        bool same_resistance_context = resistance_context_active[z] &&
          IsSameRetestContext(
            extern_high,
            extern_low,
            resistance_context_high[z],
            resistance_context_low[z],
            price_epsilon
          );

        if(!same_resistance_context)
        {
          resistance_context_active[z] = true;
          resistance_context_high[z] = extern_high;
          resistance_context_low[z] = extern_low;
          resistance_counter[z] = 0;
        }

        if(zone_hit)
        {
          resistance_counter[z]++;
          stats_array[i].fibo_retest_zones[z].resistance_retest_trigger = true;
        }

        stats_array[i].fibo_retest_zones[z].resistance_retest_count = resistance_counter[z];
        continue;
      }

      bool same_support_context = support_context_active[z] &&
        IsSameRetestContext(
          extern_high,
          extern_low,
          support_context_high[z],
          support_context_low[z],
          price_epsilon
        );

      if(!same_support_context)
      {
        support_context_active[z] = true;
        support_context_high[z] = extern_high;
        support_context_low[z] = extern_low;
        support_counter[z] = 0;
      }

      if(zone_hit)
      {
        support_counter[z]++;
        stats_array[i].fibo_retest_zones[z].support_retest_trigger = true;
      }

      stats_array[i].fibo_retest_zones[z].support_retest_count = support_counter[z];

      if(
        resistance_context_active[z] &&
        IsSameRetestContext(
          extern_high,
          extern_low,
          resistance_context_high[z],
          resistance_context_low[z],
          price_epsilon
        )
      )
      {
        stats_array[i].fibo_retest_zones[z].resistance_retest_count = resistance_counter[z];
      }
    }
  }
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

  double zone_start_levels[FIBO_RETEST_ZONES_TOTAL];
  double zone_end_levels[FIBO_RETEST_ZONES_TOTAL];

  if(FIBO_RETEST_ZONES_TOTAL >= 1)
  {
    zone_start_levels[0] = FIBO_RETEST_ZONE1_START;
    zone_end_levels[0]   = FIBO_RETEST_ZONE1_END;
  }
  if(FIBO_RETEST_ZONES_TOTAL >= 2)
  {
    zone_start_levels[1] = FIBO_RETEST_ZONE2_START;
    zone_end_levels[1]   = FIBO_RETEST_ZONE2_END;
  }

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
    for(int z = 0; z < FIBO_RETEST_ZONES_TOTAL; z++)
    {
      stats_array[i].fibo_retest_zones[z].zone_start_level = zone_start_levels[z];
      stats_array[i].fibo_retest_zones[z].zone_end_level   = zone_end_levels[z];
      stats_array[i].fibo_retest_zones[z].zone_price_low   = 0.0;
      stats_array[i].fibo_retest_zones[z].zone_price_high  = 0.0;
      stats_array[i].fibo_retest_zones[z].zone_hit         = false;
      stats_array[i].fibo_retest_zones[z].support_retest_count = 0;
      stats_array[i].fibo_retest_zones[z].resistance_retest_count = 0;
      stats_array[i].fibo_retest_zones[z].support_retest_trigger = false;
      stats_array[i].fibo_retest_zones[z].resistance_retest_trigger = false;
    }

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

      if(has_complete_range)
      {
        for(int z = 0; z < FIBO_RETEST_ZONES_TOTAL; z++)
        {
          double start_level = zone_start_levels[z];
          double end_level   = zone_end_levels[z];
          double price_start = 0.0;
          double price_end   = 0.0;
          bool   has_valid_range = false;

          if(current_is_peak)
          {
            price_start = GetFiboTrendPeakPrice(stats_array[i].extern_oldest_high, stats_array[i].extern_oldest_low, start_level);
            price_end   = GetFiboTrendPeakPrice(stats_array[i].extern_oldest_high, stats_array[i].extern_oldest_low, end_level);
          }
          else
          {
            price_start = GetFiboTrendBottomPrice(stats_array[i].extern_oldest_high, stats_array[i].extern_oldest_low, start_level);
            price_end   = GetFiboTrendBottomPrice(stats_array[i].extern_oldest_high, stats_array[i].extern_oldest_low, end_level);
          }

          if(price_start != 0.0 || price_end != 0.0)
          {
            double zone_min_price = MathMin(price_start, price_end);
            double zone_max_price = MathMax(price_start, price_end);

            if(zone_max_price > zone_min_price)
            {
              stats_array[i].fibo_retest_zones[z].zone_price_low = zone_min_price;
              stats_array[i].fibo_retest_zones[z].zone_price_high = zone_max_price;
              has_valid_range = true;
            }
            else
            {
              stats_array[i].fibo_retest_zones[z].zone_price_low = 0.0;
              stats_array[i].fibo_retest_zones[z].zone_price_high = 0.0;
            }
          }
          else
          {
            stats_array[i].fibo_retest_zones[z].zone_price_low = 0.0;
            stats_array[i].fibo_retest_zones[z].zone_price_high = 0.0;
          }

          bool zone_hit = false;

          if(has_valid_range)
          {
            if(price_start >= price_end)
            {
              zone_hit = (current_price <= price_start && current_price > price_end);
            }
            else
            {
              zone_hit = (current_price >= price_start && current_price < price_end);
            }
          }

          stats_array[i].fibo_retest_zones[z].zone_hit = zone_hit;
        }
      }
    }
  }

  UpdateRetestCounters(extrema_array, stats_array);
}

#endif // _MICROSERVICES_INDICATORS_EXTREMUM_STATISTICS_CALCULATOR_MQH_
