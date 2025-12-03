//+------------------------------------------------------------------+
//|                              market_signal_filters.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_

double ResolveBandsPercentAtShift(const BandsPercentStructure &bands_data,
                                  const int shift)
{
  switch(shift)
  {
    case 0: return bands_data.bands_percent_1;
    case 1: return bands_data.bands_percent_2;
    case 2: return bands_data.bands_percent_3;
    case 3: return bands_data.bands_percent_4;
    case 4: return bands_data.bands_percent_5;
    case 5: return bands_data.bands_percent_6;
    case 6: return bands_data.bands_percent_7;
    case 7: return bands_data.bands_percent_8;
  }
  return EMPTY_VALUE;
}

double ResolveBandsPercentMaAtShift(const BandsPercentStructure &bands_data,
                                    const int shift)
{
  switch(shift)
  {
    case 0: return bands_data.bands_percent_ma_1;
    case 1: return bands_data.bands_percent_ma_2;
    case 2: return bands_data.bands_percent_ma_3;
    case 3: return bands_data.bands_percent_ma_4;
    case 4: return bands_data.bands_percent_ma_5;
    case 5: return bands_data.bands_percent_ma_6;
    case 6: return bands_data.bands_percent_ma_7;
    case 7: return bands_data.bands_percent_ma_8;
  }
  return EMPTY_VALUE;
}

bool EvaluateBandsPercentTrigger(const BandsPercentStructure &bands_data,
                                 const SignalTypes signal_type,
                                 double percent_threshold,
                                 const StrategyEntryChannelModes entry_mode,
                                 const SlopeTypes slope_filter)
{
  if(!EntryEvaluationUsesAnyBPercent(entry_mode))
    return true;

  // Select shifted samples
  int shift_current = (int)Strategy_Channel_Indicator_Shift;
  int shift_prev = shift_current + 1;

  double percent_1 = ResolveBandsPercentAtShift(bands_data, shift_current);
  double percent_2 = ResolveBandsPercentAtShift(bands_data, shift_prev);
  double percent_ma_1 = ResolveBandsPercentMaAtShift(bands_data, shift_current);
  double percent_ma_2 = ResolveBandsPercentMaAtShift(bands_data, shift_prev);
  if(percent_1 == EMPTY_VALUE || percent_2 == EMPTY_VALUE)
    return false;
  if(percent_ma_1 == EMPTY_VALUE || percent_ma_2 == EMPTY_VALUE)
    return false;

  percent_threshold = (signal_type == BULLISH)
                        ? MathAbs(percent_threshold - 100)
                        : percent_threshold;

  bool pass = true;
  if(entry_mode == ENTRY_MODE_MA_TREND)
  {
    pass = (signal_type == BULLISH)
             ? (percent_2 < percent_threshold && (percent_1 >= percent_threshold && percent_1 < 100) && percent_ma_1 <= percent_threshold)
             : (percent_2 > percent_threshold && (percent_1 <= percent_threshold && percent_1 > 0)   && percent_ma_1 >= percent_threshold);
  }
  else if(entry_mode == ENTRY_MODE_REVERSION)
  {
    pass = (signal_type == BULLISH)
             ? (percent_2 <= percent_threshold && percent_1 > percent_threshold && percent_ma_1 <= 30)
             : (percent_2 >= percent_threshold && percent_1 < percent_threshold && percent_ma_1 >= 70);
  }
  else if(entry_mode == ENTRY_MODE_BREAKOUT)
  {
    if(signal_type == BULLISH)
      pass = (percent_1 >= percent_threshold) && (percent_2 < percent_threshold);
    else if(signal_type == BEARISH)
      pass = (percent_1 <= percent_threshold) && (percent_2 > percent_threshold);
  }

  if(!pass)
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

  bool use_teeth_branch = TrendModeUsesTeethAlligator(mode);

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
  if(StructureFilterIsEnabled(ctx.fourth_structure_filter))
    return structure.fourth_structure_time;
  if(StructureFilterIsEnabled(ctx.third_structure_filter))
    return structure.third_structure_time;
  if(StructureFilterIsEnabled(ctx.second_structure_filter))
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

bool StrategyContextEvaluateTrend(const StrategyContextIndicators &snapshot,
                                  const SignalTypes direction,
                                  bool &trend_ready,
                                  bool &trend_pass)
{
  StrategyTrendModes trend_mode = StrategyContextTrendMode(snapshot.context);
  StrategyContextTypes context = snapshot.context;
  trend_ready = false;
  trend_pass  = false;

  if(StrategyContextBPercentSlopeEnabled(context))
  {
    if(!snapshot.bpercent_valid)
      return false;
    if(!EvaluateDirectionalSlope(snapshot.bpercent_data.bands_percent_0,
                                 snapshot.bpercent_data.bands_percent_1,
                                 direction))
      return true;
  }

  if(StrategyContextStochasticSlopeEnabled(context))
  {
    if(!snapshot.stochastic_valid)
      return false;
    if(!EvaluateDirectionalSlope(snapshot.stochastic_data.stochastic_0,
                                 snapshot.stochastic_data.stochastic_1,
                                 direction))
      return true;
  }

  if(StrategyContextAlligatorSlopeEnabled(context))
  {
    if(!snapshot.alligator_valid)
      return false;
    if(!EvaluateDirectionalSlope(snapshot.alligator_data.teeth_value,
                                 snapshot.alligator_data.teeth_prev_value,
                                 direction))
      return true;
  }

  if(!TrendModeUsesAlligator(trend_mode))
  {
    trend_ready = true;
    trend_pass  = true;
    return true;
  }

  if(StrategyContextChannelFilterEnabled(context))
  {
    if(!StrategyContextChannelMaFilterAllowsSignal(context, snapshot))
      return true;
  }

  if(!snapshot.alligator_valid)
    return false;

  trend_ready = true;
  trend_pass  = EvaluateAlligatorTrend(snapshot.alligator_data,
                                       direction,
                                       trend_mode);
  return true;
}

bool StrategyContextEvaluateEntry(const StrategyContextIndicators &snapshot,
                                  const SignalTypes direction,
                                  datetime &structure_capture_time,
                                  bool &entry_allows,
                                  bool &filters_pass)
{
  structure_capture_time = 0;
  entry_allows = false;
  filters_pass = true;

  StrategyContextTypes context = snapshot.context;
  StrategyEntryChannelModes requested_entry_mode = StrategyContextEntryConfig(context);
  StrategyEntryChannelModes entry_mode = StrategyContextEntryEvaluation(context);
  bool entry_mode_disabled = (entry_mode == ENTRY_EVAL_OFF);
  bool entry_on_trend = (entry_mode == ENTRY_EVAL_ON_TREND);
  bool entry_mode_disabled_by_global = (requested_entry_mode == ENTRY_EVAL_GLOBAL &&
                                        Strategy_Global_Channel_Entry_Mode == ENTRY_EVAL_OFF);
  StrategyTrendModes trend_mode = StrategyContextTrendMode(context);
  double percent_threshold = StrategyContextIndicatorPercent(context);
  bool stoch_entry_required = (Strategy_Global_Stoch_Entry_Mode != STOCH_ENTRY_OFF);
  bool stoch_entry_pass = true;

  if(StrategyContextBPercentSlopeEnabled(context))
  {
    if(!snapshot.bpercent_valid)
      return false;
    if(!EvaluateDirectionalSlope(snapshot.bpercent_data.bands_percent_0,
                                 snapshot.bpercent_data.bands_percent_1,
                                 direction))
    {
      filters_pass = false;
      return true;
    }
  }

  if(StrategyContextStochasticSlopeEnabled(context))
  {
    if(!snapshot.stochastic_valid)
      return false;
    if(!EvaluateDirectionalSlope(snapshot.stochastic_data.stochastic_0,
                                 snapshot.stochastic_data.stochastic_1,
                                 direction))
    {
      filters_pass = false;
      return true;
    }
  }

  if(StrategyContextAlligatorSlopeEnabled(context))
  {
    if(!snapshot.alligator_valid)
      return false;
    if(!EvaluateDirectionalSlope(snapshot.alligator_data.teeth_value,
                                 snapshot.alligator_data.teeth_prev_value,
                                 direction))
    {
      filters_pass = false;
      return true;
    }
  }

  BodyVolumeFilterModes body_volume_mode = StrategyContextBodyVolumeMode(context);
  if(body_volume_mode != BODY_VOLUME_OFF)
  {
    if(!snapshot.body_ma_valid)
      return false;

    double body_value    = snapshot.body_ma_data.body_value_1;
    double body_ma_value = snapshot.body_ma_data.body_ma_1;
    double open_1        = iOpen(_Symbol, snapshot.timeframe, 1);
    double close_1       = iClose(_Symbol, snapshot.timeframe, 1);
    if(body_ma_value == EMPTY_VALUE || body_value == EMPTY_VALUE)
    {
      entry_allows = false;
      filters_pass = false;
      return true;
    }

    bool pass = true;
    if(body_volume_mode == BODY_VOLUME_HIGH)
      pass = (direction == BULLISH && close_1 > open_1 && body_value >= body_ma_value) ||
             (direction == BEARISH && close_1 < open_1 && body_value >= body_ma_value);
    else if(body_volume_mode == BODY_VOLUME_LOW)
      pass = (direction == BULLISH && close_1 >= open_1 && body_value < body_ma_value) ||
             (direction == BEARISH && close_1 <= open_1 && body_value < body_ma_value);

    if(!pass)
    {
      entry_allows = false;
      filters_pass = false;
      return true;
    }
  }

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

  if(stoch_entry_required)
  {
    if(!snapshot.stochastic_valid)
      return false;
    double stoch_signal = snapshot.stochastic_data.stochastic_signal_1;
    stoch_entry_pass = (direction == BULLISH) ? (stoch_signal < 30.0)
                                              : (stoch_signal > 70.0);
    if(!stoch_entry_pass)
    {
      entry_allows = false;
      filters_pass = false;
      return true;
    }
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

  filters_pass = true;

  if(entry_mode_disabled)
  {
    entry_allows = stoch_entry_required && stoch_entry_pass && entry_mode_disabled_by_global;
    return true;
  }

  if(entry_on_trend)
  {
    entry_allows = TrendModeUsesAlligator(trend_mode);
    return true;
  }

  bool entry_requires_bpercent = EntryEvaluationUsesAnyBPercent(entry_mode);
  bool bpercent_pass = true;
  if(entry_requires_bpercent && percent_threshold >= 0.0)
  {
    if(!snapshot.bpercent_valid)
      return false;
    bpercent_pass = EvaluateBandsPercentTrigger(snapshot.bpercent_data,
                                                direction,
                                                percent_threshold,
                                                entry_mode,
                                                NO_SLOPE);
    if(!bpercent_pass)
    {
      entry_allows = false;
      return true;
    }
  }

  entry_allows = (!entry_requires_bpercent || percent_threshold < 0.0 || bpercent_pass);
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
