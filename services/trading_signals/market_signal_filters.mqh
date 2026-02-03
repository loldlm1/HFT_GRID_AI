//+------------------------------------------------------------------+
//|                              market_signal_filters.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_

bool EvaluateDirectionalSlope(const double current_value,
                              const double previous_value,
                              const SignalTypes signal_type)
{
  if(signal_type == BULLISH)
    return current_value >= previous_value;
  if(signal_type == BEARISH)
    return current_value <= previous_value;
  return true;
}

bool ResolveStructureReferenceRange(const StochasticMarketStructure &structure,
                                    double &peak_price,
                                    double &bottom_price)
{
  peak_price = 0.0;
  bottom_price = 0.0;

  int total = ArraySize(structure.os_market_structures);
  if(total < 4)
    return false;

  bool initial_is_peak = structure.os_market_structures[0].is_peak;
  bool initial_is_bottom = !initial_is_peak;

  int structure_peaks_index   = initial_is_bottom ? 1 : 0;
  int structure_bottoms_index = initial_is_peak   ? 1 : 0;

  if(initial_is_bottom)
  {
    peak_price   = structure.os_market_structures[structure_bottoms_index + 1].extremum_high;
    bottom_price = structure.os_market_structures[structure_bottoms_index + 2].extremum_low;
  }
  else
  {
    peak_price   = structure.os_market_structures[structure_peaks_index + 2].extremum_high;
    bottom_price = structure.os_market_structures[structure_peaks_index + 1].extremum_low;
  }

  return (peak_price > 0.0 && bottom_price > 0.0 && peak_price != bottom_price);
}

bool ResolveStructurePercentForPrice(const double peak_price,
                                     const double bottom_price,
                                     const SignalTypes direction,
                                     const double price,
                                     double &percent_out)
{
  percent_out = 0.0;
  if(direction == BULLISH)
  {
    percent_out = GetFiboTrendBottomPercent(peak_price, bottom_price, price);
    return percent_out > 0.0;
  }
  if(direction == BEARISH)
  {
    percent_out = GetFiboTrendPeakPercent(peak_price, bottom_price, price);
    return percent_out > 0.0;
  }
  return false;
}

bool ResolveStructurePriceForPercent(const double peak_price,
                                     const double bottom_price,
                                     const SignalTypes direction,
                                     const double percent,
                                     double &price_out)
{
  price_out = 0.0;
  if(direction == BULLISH)
  {
    price_out = GetFiboTrendBottomPrice(peak_price, bottom_price, percent);
    return price_out > 0.0;
  }
  if(direction == BEARISH)
  {
    price_out = GetFiboTrendPeakPrice(peak_price, bottom_price, percent);
    return price_out > 0.0;
  }
  return false;
}

bool FetchStructureForContext(const StrategyContextIndicators &snapshot,
                              StochasticMarketStructure &structure)
{
  if(!snapshot.structure_valid)
    return false;
  structure = snapshot.structure_data;
  return true;
}

datetime ResolveStructureSnapshotTimestamp(const StochasticMarketStructure &structure,
                                           const StrategyStructureLayerContext &ctx)
{
  bool all_filters_disabled =
    !StructureFilterIsEnabled(ctx.first_structure_filter)  &&
    !StructureFilterIsEnabled(ctx.second_structure_filter) &&
    !StructureFilterIsEnabled(ctx.third_structure_filter)  &&
    !StructureFilterIsEnabled(ctx.fourth_structure_filter);

  if(StructureFilterIsEnabled(ctx.fourth_structure_filter))
    return structure.fourth_structure_time;
  if(StructureFilterIsEnabled(ctx.third_structure_filter))
    return structure.third_structure_time;
  if(StructureFilterIsEnabled(ctx.second_structure_filter))
    return structure.second_structure_time;
  if(StructureFilterIsEnabled(ctx.first_structure_filter))
    return structure.first_structure_time;

  // No structure filters enabled: use the second structure timestamp when available to
  // avoid reusing the same bar for fresh-structure checks.
  if(all_filters_disabled && structure.second_structure_time > 0)
    return structure.second_structure_time;

  return structure.first_structure_time;
}

bool ValidateFreshStructureTimestamp(const StrategyContextTypes context,
                                     const StrategyContextIndicators &snapshot,
                                     const StrategyStructureLayerContext &ctx,
                                     const SignalTypes direction,
                                     datetime &captured_time)
{
  captured_time = 0;
  if(!ctx.enabled)
    return true;

  if(!StrategyContextFreshStructureEnabled(context))
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForContext(snapshot, structure))
    return false;

  datetime structure_time = ResolveStructureSnapshotTimestamp(structure, ctx);
  if(structure_time <= 0)
    return false;

  datetime last_time = GetLastContextStructureTime(context, direction);
  if(last_time > 0 && structure_time <= last_time)
    return false;

  captured_time = structure_time;
  return true;
}

bool ValidateExternStructuresRequirement(const ExtremumStatistics &latest_stats,
                                         const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return true;
  if(ctx.min_extern_structures <= 0)
    return true;
  return latest_stats.extern_structures_broken >= ctx.min_extern_structures;
}

bool ValidateRetestRequirements(const ExtremumStatistics &latest_stats,
                                const SignalTypes signal_type,
                                const StrategyStructureLayerContext &ctx)
{
  if(!ctx.enabled)
    return true;
  for(int zone_index = 0; zone_index < FIBO_RETEST_ZONES_TOTAL; zone_index++)
  {
    int required = ResolveRetestRequirement(ctx, signal_type, zone_index);
    if(required <= 0)
      continue;

    int available = 0;
    if(signal_type == BULLISH)
      available = latest_stats.fibo_retest_zones[zone_index].support_retest_count;
    if(signal_type == BEARISH)
      available = latest_stats.fibo_retest_zones[zone_index].resistance_retest_count;

    if(available < required)
      return false;
  }

  return true;
}

bool EvaluateStructureRetestTrigger(const StrategyContextIndicators &snapshot,
                                    const SignalTypes signal_type,
                                    const StrategyStructureLayerContext &ctx)
{
  bool require_support_resistance = StructureFiltersRequested(ctx, signal_type);
  bool require_extern_breaks = (ctx.enabled && ctx.min_extern_structures > 0);

  if(!require_support_resistance && !require_extern_breaks)
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForContext(snapshot, structure))
    return false;

  if(StrategyContextFirstStructureUsesClosePercent(snapshot.context) && require_support_resistance)
  {
    double live_close_percent = structure.first_structure_close_percent;
    if(!StructureLivePercentSatisfiesFilter(ctx, signal_type, live_close_percent))
      return false;
  }

  if(ArraySize(structure.extremum_stats) <= 0)
    return false;

  ExtremumStatistics latest_stats = structure.extremum_stats[0];

  if(require_extern_breaks && !ValidateExternStructuresRequirement(latest_stats, ctx))
    return false;

  if(require_support_resistance && !ValidateRetestRequirements(latest_stats, signal_type, ctx))
    return false;

  return true;
}

bool TrendStructureFilterMatches(const TrendStructureFilterModes filter_mode,
                                 const OscillatorStructureTypes structure_type,
                                 const SignalTypes signal_type,
                                 const OscillatorMarketStructure &latest_extremum)
{
  if(filter_mode == BULLISH_STRUCT_OFF || filter_mode == BEARISH_STRUCT_OFF)
    return true;

  bool skip_eq_allowance = (filter_mode == BULLISH_STRUCT_HH_LH ||
                            filter_mode == BEARISH_STRUCT_LL_HL);
  if(!skip_eq_allowance)
  {
    if(signal_type == BULLISH && !latest_extremum.is_peak && structure_type == OSCILLATOR_STRUCTURE_EQ)
      return true;
    if(signal_type == BEARISH && latest_extremum.is_peak  && structure_type == OSCILLATOR_STRUCTURE_EQ)
      return true;
  }

  bool struct_match = true;
  switch(filter_mode)
  {
    case BULLISH_STRUCT_LL:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_LL);
      break;
    case BULLISH_STRUCT_LH:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_LH);
      break;
    case BULLISH_STRUCT_LL_LH:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_LL ||
                      structure_type == OSCILLATOR_STRUCTURE_LH);
      break;
    case BULLISH_STRUCT_HH_LH:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_HH ||
                      structure_type == OSCILLATOR_STRUCTURE_LH);
      break;
    case BEARISH_STRUCT_HH:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_HH);
      break;
    case BEARISH_STRUCT_HL:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_HL);
      break;
    case BEARISH_STRUCT_HH_HL:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_HH ||
                      structure_type == OSCILLATOR_STRUCTURE_HL);
      break;
    case BEARISH_STRUCT_LL_HL:
      struct_match = (structure_type == OSCILLATOR_STRUCTURE_LL ||
                      structure_type == OSCILLATOR_STRUCTURE_HL);
      break;
    default:
      struct_match = true;
      break;
  }

  if(!struct_match)
    return false;

  bool filter_is_bullish =
    (filter_mode == BULLISH_STRUCT_LL) ||
    (filter_mode == BULLISH_STRUCT_LH) ||
    (filter_mode == BULLISH_STRUCT_LL_LH) ||
    (filter_mode == BULLISH_STRUCT_HH_LH);

  bool filter_is_bearish =
    (filter_mode == BEARISH_STRUCT_HH) ||
    (filter_mode == BEARISH_STRUCT_HL) ||
    (filter_mode == BEARISH_STRUCT_HH_HL) ||
    (filter_mode == BEARISH_STRUCT_LL_HL);

  if(!skip_eq_allowance)
  {
    if(filter_is_bullish && signal_type == BULLISH)
    {
      if(latest_extremum.is_peak)
        return false;
    }

    if(filter_is_bearish && signal_type == BEARISH)
    {
      if(!latest_extremum.is_peak)
        return false;
    }
  }

  return true;
}

bool EvaluateStructureTypeFilters(const StrategyContextIndicators &snapshot,
                                  const StrategyStructureLayerContext &ctx,
                                  const SignalTypes signal_type)
{
  if(!StructureTypeFiltersRequested(ctx))
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForContext(snapshot, structure))
    return false;

  OscillatorMarketStructure latest_extremum;
  if(ArraySize(structure.os_market_structures) <= 0)
    return false;
  latest_extremum = structure.os_market_structures[0];

  bool first_pass  = TrendStructureFilterMatches(ctx.first_structure_filter,
                                                 structure.first_structure_type,
                                                 signal_type,
                                                 latest_extremum);
  bool second_pass = TrendStructureFilterMatches(ctx.second_structure_filter,
                                                 structure.second_structure_type,
                                                 signal_type,
                                                 latest_extremum);
  bool third_pass  = TrendStructureFilterMatches(ctx.third_structure_filter,
                                                 structure.third_structure_type,
                                                 signal_type,
                                                 latest_extremum);
  bool fourth_pass = TrendStructureFilterMatches(ctx.fourth_structure_filter,
                                                 structure.fourth_structure_type,
                                                 signal_type,
                                                 latest_extremum);

  return first_pass && second_pass && third_pass && fourth_pass;
}

bool StructureLivePercentSatisfiesFilter(const StrategyStructureLayerContext &ctx,
                                         const SignalTypes signal_type,
                                         const double live_percent)
{
  if(live_percent <= 0.0)
    return false;

  bool support_filter_active    = (signal_type == BULLISH) && (ctx.support_filter != SUPPORT_DISABLED);
  bool resistance_filter_active = (signal_type == BEARISH) && (ctx.resistance_filter != RESISTANCE_DISABLED);

  if(!support_filter_active && !resistance_filter_active)
    return true;

  double lower = 0.0;
  double upper = 0.0;

  if(signal_type == BULLISH)
  {
    if(ctx.support_filter == SUPPORT_61)
    {
      lower = FIBO_RETEST_ZONE1_START;
      upper = FIBO_RETEST_ZONE1_END;
    }
    else if(ctx.support_filter == SUPPORT_78)
    {
      lower = FIBO_RETEST_ZONE2_START;
      upper = FIBO_RETEST_ZONE2_END;
    }
  }
  else if(signal_type == BEARISH)
  {
    if(ctx.resistance_filter == RESISTANCE_61)
    {
      lower = FIBO_RETEST_ZONE1_START;
      upper = FIBO_RETEST_ZONE1_END;
    }
    else if(ctx.resistance_filter == RESISTANCE_78)
    {
      lower = FIBO_RETEST_ZONE2_START;
      upper = FIBO_RETEST_ZONE2_END;
    }
  }

  if(lower == 0.0 && upper == 0.0)
    return true;

  return (live_percent >= lower && live_percent <= upper);
}

bool ResolveStructureFibonacciEntry(const StrategyContextIndicators &snapshot,
                                    const SignalTypes direction,
                                    const StructureTriggerEntryModes trigger_mode,
                                    double &entry_price_out,
                                    bool &in_zone,
                                    bool &entry_is_limit)
{
  entry_price_out = 0.0;
  in_zone = false;
  entry_is_limit = false;

  if(!snapshot.structure_valid)
    return false;
  if(!g_structure_fibo_config.valid)
    return false;

  double peak_price = 0.0;
  double bottom_price = 0.0;
  if(!ResolveStructureReferenceRange(snapshot.structure_data, peak_price, bottom_price))
    return false;

  double close_price = iClose(_Symbol, snapshot.timeframe, 0);
  double low_price   = iLow(_Symbol, snapshot.timeframe, 0);
  double high_price  = iHigh(_Symbol, snapshot.timeframe, 0);

  double close_percent = 0.0;
  double extreme_percent = 0.0;

  if(!ResolveStructurePercentForPrice(peak_price, bottom_price, direction, close_price, close_percent))
    return false;

  if(direction == BULLISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price, bottom_price, direction, low_price, extreme_percent))
      extreme_percent = close_percent;
  }
  else if(direction == BEARISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price, bottom_price, direction, high_price, extreme_percent))
      extreme_percent = close_percent;
  }

  double lower = 0.0;
  double upper = 0.0;
  bool range_ok = ResolveFibonacciRangeForPercent(g_structure_fibo_config.levels,
                                                  ArraySize(g_structure_fibo_config.levels),
                                                  close_percent,
                                                  lower,
                                                  upper);
  bool close_in = false;
  bool extreme_in = false;
  if(range_ok)
  {
    close_in = (close_percent >= lower && close_percent <= upper);
    extreme_in = (extreme_percent >= lower && extreme_percent <= upper);
  }

  if(!close_in && !extreme_in)
  {
    double ext_lower = 0.0;
    double ext_upper = 0.0;
    if(ResolveFibonacciRangeForPercent(g_structure_fibo_config.levels,
                                       ArraySize(g_structure_fibo_config.levels),
                                       extreme_percent,
                                       ext_lower,
                                       ext_upper))
    {
      if(extreme_percent >= ext_lower && extreme_percent <= ext_upper)
      {
        lower = ext_lower;
        upper = ext_upper;
        extreme_in = true;
      }
    }
  }

  if(!close_in && !extreme_in)
    return true; // no trigger but not fatal

  double required_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
  if(required_points > 0.0)
  {
    double lower_price = 0.0;
    double upper_price = 0.0;
    if(ResolveStructurePriceForPercent(peak_price, bottom_price, direction, lower, lower_price) &&
       ResolveStructurePriceForPercent(peak_price, bottom_price, direction, upper, upper_price))
    {
      double point_size = GridResolvePointSizeSafe();
      double range_points = (point_size > 0.0)
                              ? MathAbs(lower_price - upper_price) / point_size
                              : 0.0;
      if(range_points < required_points)
        return true; // range too tight, skip entry
    }
  }

  in_zone = true;
  entry_is_limit = (trigger_mode == LEVELS_AS_LIMITS);

  if(entry_is_limit)
  {
    if(!ResolveStructurePriceForPercent(peak_price, bottom_price, direction, upper, entry_price_out))
      return false;
  }
  else
  {
    entry_price_out = close_price; // market execution at current close
  }

  return true;
}

bool StrategyContextEvaluateEntry(const StrategyContextIndicators &snapshot,
                                  const SignalTypes direction,
                                  datetime &structure_capture_time,
                                  bool &entry_allows,
                                  bool &filters_pass,
                                  double &entry_price_out,
                                  bool &entry_is_limit)
{
  structure_capture_time = 0;
  entry_allows = false;
  filters_pass = true;
  entry_price_out = 0.0;
  entry_is_limit = false;

  StrategyContextTypes context = snapshot.context;

  StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(context);
  if(!EvaluateStructureRetestTrigger(snapshot, direction, structure_ctx))
  {
    entry_allows = false;
    filters_pass = false;
    return true;
  }

  if(!EvaluateStructureTypeFilters(snapshot, structure_ctx, direction))
  {
    entry_allows = false;
    filters_pass = false;
    return true;
  }

  bool enforce_fresh = StrategyContextFreshStructureEnabled(context) && structure_ctx.enabled;
  if(enforce_fresh)
  {
    if(!ValidateFreshStructureTimestamp(context,
                                        snapshot,
                                        structure_ctx,
                                        direction,
                                        structure_capture_time))
    {
      entry_allows = false;
      filters_pass = false;
      return true;
    }
  }

  double entry_price = 0.0;
  bool in_zone = false;
  bool resolved_is_limit = false;
  if(!ResolveStructureFibonacciEntry(snapshot,
                                     direction,
                                     Structure_Trigger_Entry,
                                     entry_price,
                                     in_zone,
                                     resolved_is_limit))
    return false;

  filters_pass = true;
  entry_allows = in_zone;
  if(in_zone)
  {
    entry_price_out = entry_price;
    entry_is_limit = resolved_is_limit;
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
