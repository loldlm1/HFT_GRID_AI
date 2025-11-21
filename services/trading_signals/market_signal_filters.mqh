//+------------------------------------------------------------------+
//|                              market_signal_filters.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_

bool ValidateBandsPercentWindowBias(const BandsPercentStructure &bands_data,
                                    const SignalTypes signal_type,
                                    double percent_threshold)
{
  double window_high = bands_data.bands_percent_window_high;
  double window_low  = bands_data.bands_percent_window_low;

  if(window_high == EMPTY_VALUE || window_low == EMPTY_VALUE)
    return false;

  double buffer = 30.0;
  percent_threshold = signal_type == BULLISH ? MathAbs(percent_threshold-100) : percent_threshold;

  if(signal_type == BULLISH)
  {
    bool discount_entry = (window_low <= percent_threshold) &&
                          (window_low >= percent_threshold - buffer);
    bool premium_memory = (window_high >= percent_threshold);
    return discount_entry && premium_memory;
  }
  else if(signal_type == BEARISH)
  {
    bool premium_entry = (window_high >= percent_threshold) &&
                         (window_high <= percent_threshold + buffer);
    bool discount_memory = (window_low <= percent_threshold);
    return premium_entry && discount_memory;
  }

  return false;
}

bool ValidateBandsPercentMeanRejection(const BandsPercentStructure &bands_data,
                                       const SignalTypes signal_type,
                                       double percent_threshold)
{
  double percent_1 = bands_data.bands_percent_1;
  double percent_2 = bands_data.bands_percent_2;

  if(percent_1 == EMPTY_VALUE || percent_2 == EMPTY_VALUE)
    return false;

  double tolerance = 10.0;
  percent_threshold = signal_type == BULLISH ? MathAbs(percent_threshold-100) : percent_threshold;

  if(signal_type == BULLISH)
  {
    bool dipped_discount = (percent_2 <= percent_threshold);
    bool recovered_zone  = (percent_1 > percent_threshold) &&
                           (percent_1 < percent_threshold + tolerance);
    return dipped_discount && recovered_zone;
  }
  else if(signal_type == BEARISH)
  {
    bool spiked_premium = (percent_2 >= percent_threshold);
    bool rolled_zone    = (percent_1 < percent_threshold) &&
                          (percent_1 > percent_threshold - tolerance);
    return spiked_premium && rolled_zone;
  }

  return false;
}

bool EvaluateBandsPercentTrigger(const BandsPercentStructure &bands_data,
                                 const SignalTypes signal_type,
                                 const double percent_threshold,
                                 const StrategyTrendModes mode,
                                 const SlopeTypes slope_filter)
{
  if(!StrategyModeUsesAnyBPercent(mode))
    return true;

  bool window_required = StrategyModeUsesBPercentWindow(mode);
  bool mean_required   = StrategyModeUsesBPercentMean(mode);

  bool window_ok = true;
  bool mean_ok   = true;

  if(window_required)
    window_ok = ValidateBandsPercentWindowBias(bands_data, signal_type, percent_threshold);
  if(mean_required)
    mean_ok = ValidateBandsPercentMeanRejection(bands_data, signal_type, percent_threshold);

  if(!window_ok || !mean_ok)
    return false;

  if(slope_filter == NO_SLOPE)
    return true;

  return (bands_data.bands_percent_slope_0 == slope_filter);
}

bool EvaluateAlligatorTrend(const AlligatorStructure &alligator_data,
                            const SignalTypes signal_type,
                            const StrategyTrendModes mode)
{
  double jaws_value  = alligator_data.jaws_value;
  double teeth_value = alligator_data.teeth_value;
  double lips_value  = alligator_data.lips_value;

  bool use_teeth_branch = StrategyModeUsesTeethAlligator(mode);

  if(use_teeth_branch)
  {
    if(signal_type == BULLISH)
      return (lips_value > teeth_value && teeth_value > jaws_value);
    if(signal_type == BEARISH)
      return (lips_value < teeth_value && teeth_value < jaws_value);
    return false;
  }

  if(signal_type == BULLISH)
    return (lips_value > jaws_value && teeth_value > jaws_value);
  if(signal_type == BEARISH)
    return (lips_value < jaws_value && teeth_value < jaws_value);
  return false;
}

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

bool EvaluateBaseIndicatorTrigger(const SignalParams &signal_params,
                                  const SignalTypes signal_type,
                                  const double percent_threshold)
{
  bool uses_bpercent  = StrategyModeUsesAnyBPercent(Strategy_Base_Mode);
  bool uses_alligator = StrategyModeUsesAlligator(Strategy_Base_Mode);

  bool bpercent_pass  = true;
  bool alligator_pass = true;

  if(uses_bpercent)
  {
    if(percent_threshold >= 0.0)
    {
      int total_entries = ArraySize(signal_params.bands_percent_data);
      if(total_entries <= 0)
        return false;

      BandsPercentStructure bands_data = signal_params.bands_percent_data[0];
      bpercent_pass = EvaluateBandsPercentTrigger(bands_data,
                                                  signal_type,
                                                  percent_threshold,
                                                  Strategy_Base_Mode,
                                                  NO_SLOPE);
    }
  }

  if(uses_alligator)
  {
    int total_alligator_entries = ArraySize(signal_params.alligator_data);
    if(total_alligator_entries <= 0)
      return false;

    AlligatorStructure alligator_data = signal_params.alligator_data[0];
    alligator_pass = EvaluateAlligatorTrend(alligator_data,
                                            signal_type,
                                            Strategy_Base_Mode);
  }

  bool slope_bpercent_pass = true;
  if(Base_BPercent_Slope_Filter)
  {
    int total_entries = ArraySize(signal_params.bands_percent_data);
    if(total_entries <= 0)
      return false;
    BandsPercentStructure bands_data = signal_params.bands_percent_data[0];
    slope_bpercent_pass = EvaluateDirectionalSlope(bands_data.bands_percent_0,
                                                   bands_data.bands_percent_1,
                                                   signal_type);
  }

  bool slope_alligator_pass = true;
  if(Base_Alligator_Slope_Filter)
  {
    int total_alligator_entries = ArraySize(signal_params.alligator_data);
    if(total_alligator_entries <= 0)
      return false;
    AlligatorStructure alligator_data = signal_params.alligator_data[0];
    slope_alligator_pass = EvaluateDirectionalSlope(alligator_data.teeth_value,
                                                    alligator_data.teeth_prev_value,
                                                    signal_type);
  }

  bool slope_stoch_pass = true;
  if(Base_Stochastic_Slope_Filter)
  {
    int total_stoch = ArraySize(signal_params.stochastic_data);
    if(total_stoch <= 0)
      return false;
    StochasticStructure stoch_data = signal_params.stochastic_data[0];
    slope_stoch_pass = EvaluateDirectionalSlope(stoch_data.stochastic_0,
                                                stoch_data.stochastic_1,
                                                signal_type);
  }

  bool mode_pass = true;
  if(StrategyModeUsesAnyBPercent(Strategy_Base_Mode))
    mode_pass = mode_pass && bpercent_pass;
  if(StrategyModeUsesAlligator(Strategy_Base_Mode))
    mode_pass = mode_pass && alligator_pass;

  return mode_pass &&
         slope_bpercent_pass &&
         slope_alligator_pass &&
         slope_stoch_pass;
}

bool TrendFilterAllowsSignal(const SignalParams &signal_params,
                             const SignalTypes direction)
{
  if(!TrendContextEnabled() || signal_params.trend_filter_mode == TREND_OFF)
    return true;
  bool percent_ok = true;
  bool alligator_ok = true;
  StrategyTrendModes filter_mode = signal_params.trend_filter_mode;

  if(StrategyModeUsesAnyBPercent(filter_mode) && Trend_Indicator_Percent >= 0.0)
  {
    if(!signal_params.trend_bpercent_valid)
      return false;
    percent_ok = EvaluateBandsPercentTrigger(signal_params.trend_bpercent_data,
                                             direction,
                                             Trend_Indicator_Percent,
                                             filter_mode,
                                             NO_SLOPE);
    if(!percent_ok)
      return false;
  }

  if(StrategyModeUsesAlligator(filter_mode))
  {
    if(!signal_params.trend_alligator_valid)
      return false;
    alligator_ok = EvaluateAlligatorTrend(signal_params.trend_alligator_data,
                                          direction,
                                          filter_mode);
    if(!alligator_ok)
      return false;
  }

  if(Trend_BPercent_Slope_Filter)
  {
    if(!signal_params.trend_bpercent_valid)
      return false;
    double current = signal_params.trend_bpercent_data.bands_percent_0;
    double previous = signal_params.trend_bpercent_data.bands_percent_1;
    if(!EvaluateDirectionalSlope(current, previous, direction))
      return false;
  }

  if(Trend_Stochastic_Slope_Filter)
  {
    if(!signal_params.trend_stochastic_valid)
      return false;

    double current = signal_params.trend_stochastic_data.stochastic_0;
    double previous = signal_params.trend_stochastic_data.stochastic_1;
    if(!EvaluateDirectionalSlope(current, previous, direction))
      return false;
  }

  if(Trend_Alligator_Slope_Filter)
  {
    if(!signal_params.trend_alligator_valid)
      return false;
    double current = signal_params.trend_alligator_data.lips_value;
    double previous = signal_params.trend_alligator_data.lips_prev_value;
    if(!EvaluateDirectionalSlope(current, previous, direction))
      return false;
  }

  return true;
}

bool FetchStructureForFilters(const SignalParams &signal_params,
                              StochasticMarketStructure &structure,
                              const StrategyStructureLayerContext &ctx)
{
  if(ctx.enabled && ctx.uses_trend_dataset)
  {
    if(signal_params.trend_structure_valid)
    {
      structure = signal_params.trend_structure_data;
      return true;
    }
    return false;
  }

  int total_structures = ArraySize(signal_params.stoch_market_structure_data);
  if(total_structures <= 0)
    return false;

  structure = signal_params.stoch_market_structure_data[0];
  return true;
}

datetime ResolveStructureSnapshotTimestamp(const StochasticMarketStructure &structure,
                                           const StrategyStructureLayerContext &ctx)
{
  bool use_second_structure = StructureFilterIsEnabled(ctx.second_structure_filter);
  if(use_second_structure)
    return structure.second_structure_time;
  return structure.first_structure_time;
}

bool ValidateFreshStructureTimestamp(const SignalParams &signal_params,
                                     const StrategyStructureLayerContext &ctx,
                                     const SignalTypes direction,
                                     const bool is_trend_context,
                                     datetime &captured_time)
{
  captured_time = 0;
  if(!ctx.enabled)
    return true;

  bool enforce = is_trend_context ? Trend_Fresh_Structure_Time : Base_Fresh_Structure_Time;
  if(!enforce)
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForFilters(signal_params, structure, ctx))
    return false;

  datetime structure_time = ResolveStructureSnapshotTimestamp(structure, ctx);
  if(structure_time <= 0)
    return false;

  int idx = DirectionIndex(direction);
  datetime last_time = is_trend_context ? g_last_trend_structure_time[idx]
                                        : g_last_base_structure_time[idx];
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

bool EvaluateStructureRetestTrigger(const SignalParams &signal_params,
                                    const SignalTypes signal_type,
                                    const StrategyStructureLayerContext &ctx)
{
  bool require_support_resistance = StructureFiltersRequested(ctx, signal_type);
  bool require_extern_breaks = (ctx.enabled && ctx.min_extern_structures > 0);

  if(!require_support_resistance && !require_extern_breaks)
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForFilters(signal_params, structure, ctx))
    return false;

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

  if(filter_mode == BULLISH_STRUCT_OFF_FINAL || filter_mode == BEARISH_STRUCT_OFF_FINAL)
    return true;

  if(signal_type == BULLISH && !latest_extremum.is_peak && structure_type == OSCILLATOR_STRUCTURE_EQ)
    return true;
  if(signal_type == BEARISH && latest_extremum.is_peak  && structure_type == OSCILLATOR_STRUCTURE_EQ)
    return true;

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
    default:
      struct_match = true;
      break;
  }

  if(!struct_match)
    return false;

  bool filter_is_bullish =
    (filter_mode == BULLISH_STRUCT_LL) ||
    (filter_mode == BULLISH_STRUCT_LH) ||
    (filter_mode == BULLISH_STRUCT_LL_LH);

  bool filter_is_bearish =
    (filter_mode == BEARISH_STRUCT_HH) ||
    (filter_mode == BEARISH_STRUCT_HL) ||
    (filter_mode == BEARISH_STRUCT_HH_HL);

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

  return true;
}

bool EvaluateStructureTypeFilters(const SignalParams &signal_params,
                                  const StrategyStructureLayerContext &ctx,
                                  const SignalTypes signal_type)
{
  if(!StructureTypeFiltersRequested(ctx))
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForFilters(signal_params, structure, ctx))
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

  return first_pass && second_pass;
}

bool EvaluateSignalTrigger(SignalParams &signal_params, const SignalTypes signal_type)
{
  StrategyStructureLayerContext base_ctx  = BuildBaseStructureLayerContext();
  StrategyStructureLayerContext trend_ctx = BuildTrendStructureLayerContext();

  datetime base_fresh_time  = 0;
  datetime trend_fresh_time = 0;

  if(!ValidateFreshStructureTimestamp(signal_params,
                                      base_ctx,
                                      signal_type,
                                      false,
                                      base_fresh_time))
    return false;

  if(!ValidateFreshStructureTimestamp(signal_params,
                                      trend_ctx,
                                      signal_type,
                                      true,
                                      trend_fresh_time))
    return false;

  bool base_trigger             = EvaluateBaseIndicatorTrigger(signal_params,
                                                               signal_type,
                                                               Base_Indicator_Percent);
  bool base_structure_filters   = EvaluateStructureRetestTrigger(signal_params,
                                                                 signal_type,
                                                                 base_ctx);
  bool trend_structure_filters  = EvaluateStructureRetestTrigger(signal_params,
                                                                 signal_type,
                                                                 trend_ctx);
  bool base_structure_types     = EvaluateStructureTypeFilters(signal_params, base_ctx, signal_type);
  bool trend_structure_types    = EvaluateStructureTypeFilters(signal_params, trend_ctx, signal_type);

  signal_params.base_structure_snapshot_time  = base_fresh_time;
  signal_params.trend_structure_snapshot_time = trend_fresh_time;

  return base_trigger &&
         base_structure_filters &&
         trend_structure_filters &&
         base_structure_types &&
         trend_structure_types;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
