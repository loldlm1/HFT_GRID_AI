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

bool CandleStructurePairMatches(const CandleStrategyTypes mode,
                                const double high_current,
                                const double low_current,
                                const double high_past,
                                const double low_past)
{
  switch(mode)
  {
    case OFF_CANDLE_STRUCTURE:
      return true;
    case SHRINKED_CANDLE_STRUCTURE:
      return (high_current <= high_past && low_current >= low_past);
    case EXPANDED_CANDLE_STRUCTURE:
      return (high_current > high_past && low_current < low_past);
    case BULLISH_CANDLE_STRUCTURE:
      return (high_current > high_past && low_current > low_past);
    case BEARISH_CANDLE_STRUCTURE:
      return (high_current < high_past && low_current < low_past);
    default:
      return false;
  }
}

bool EvaluateCandleStructureChain(const CandleStrategyTypes mode,
                                  const double &high_values[],
                                  const double &low_values[],
                                  const int shift,
                                  const int depth)
{
  if(!CandleStructureFilterEnabled(mode))
    return true;

  int resolved_shift = ResolveCandleStructureShift(shift);
  int resolved_depth = ResolveCandleStructureDepth(depth);
  int required_bars = ResolveCandleStructureRequiredBars(resolved_shift, resolved_depth);

  if(ArraySize(high_values) < required_bars || ArraySize(low_values) < required_bars)
    return false;

  for(int step = 0; step < resolved_depth; step++)
  {
    int current_index = resolved_shift + step;
    int past_index = current_index + 1;

    double high_current = high_values[current_index];
    double low_current = low_values[current_index];
    double high_past = high_values[past_index];
    double low_past = low_values[past_index];

    if(!MathIsValidNumber(high_current) ||
       !MathIsValidNumber(low_current) ||
       !MathIsValidNumber(high_past) ||
       !MathIsValidNumber(low_past))
      return false;

    if(!CandleStructurePairMatches(mode,
                                   high_current,
                                   low_current,
                                   high_past,
                                   low_past))
      return false;
  }

  return true;
}

bool EvaluateCandleStructureFilter(const ENUM_TIMEFRAMES timeframe,
                                   const CandleStrategyTypes mode,
                                   const int shift,
                                   const int depth)
{
  if(!CandleStructureFilterEnabled(mode))
    return true;

  ENUM_TIMEFRAMES resolved_timeframe = ResolveCandleStructureTimeframe(timeframe);
  int resolved_shift = ResolveCandleStructureShift(shift);
  int resolved_depth = ResolveCandleStructureDepth(depth);
  int required_bars = ResolveCandleStructureRequiredBars(resolved_shift, resolved_depth);

  if(Bars(_Symbol, resolved_timeframe) < required_bars)
    return false;

  double high_values[];
  double low_values[];
  ArraySetAsSeries(high_values, true);
  ArraySetAsSeries(low_values, true);

  int copied_high = CopyHigh(_Symbol,
                             resolved_timeframe,
                             0,
                             required_bars,
                             high_values);
  int copied_low = CopyLow(_Symbol,
                           resolved_timeframe,
                           0,
                           required_bars,
                           low_values);

  if(copied_high < required_bars || copied_low < required_bars)
    return false;

  return EvaluateCandleStructureChain(mode,
                                      high_values,
                                      low_values,
                                      resolved_shift,
                                      resolved_depth);
}

bool EvaluateCandleStructureFilter()
{
  return EvaluateCandleStructureFilter(Candle_Timeframe,
                                       Candle_Strategy_Type,
                                       Candle_Strategy_Shift,
                                       Candle_Strategy_Depth);
}

bool ResolveStructureReferenceRange(const StochasticMarketStructure &structure,
                                    double &peak_price,
                                    double &bottom_price,
                                    bool &current_is_bottom)
{
  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;

  int total = ArraySize(structure.os_market_structures);
  if(total < 3)
    return false;

  bool first_is_peak = structure.os_market_structures[1].is_peak;
  bool second_is_peak = structure.os_market_structures[2].is_peak;
  if(first_is_peak == second_is_peak)
    return false;

  current_is_bottom = !second_is_peak;

  if(current_is_bottom)
  {
    peak_price   = structure.os_market_structures[1].extremum_high;
    bottom_price = structure.os_market_structures[2].extremum_low;
  }
  else
  {
    peak_price   = structure.os_market_structures[2].extremum_high;
    bottom_price = structure.os_market_structures[1].extremum_low;
  }

  return (peak_price > 0.0 && bottom_price > 0.0 && peak_price != bottom_price);
}

bool ResolveStructurePercentForPrice(const double peak_price,
                                     const double bottom_price,
                                     const bool current_is_bottom,
                                     const double price,
                                     double &percent_out)
{
  percent_out = 0.0;

  if(current_is_bottom)
    percent_out = GetFiboTrendBottomPercent(peak_price, bottom_price, price);
  else
    percent_out = GetFiboTrendPeakPercent(peak_price, bottom_price, price);

  return MathIsValidNumber(percent_out) && percent_out >= 0.0;
}

bool ResolveStructurePriceForPercent(const double peak_price,
                                     const double bottom_price,
                                     const bool current_is_bottom,
                                     const double percent,
                                     double &price_out)
{
  price_out = 0.0;

  if(current_is_bottom)
    price_out = GetFiboTrendBottomPrice(peak_price, bottom_price, percent);
  else
    price_out = GetFiboTrendPeakPrice(peak_price, bottom_price, percent);

  return price_out > 0.0;
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
                                           const StrategyStructureLayerContext &)
{
  // Keep the immutable second slot as the preferred snapshot timestamp for
  // fresh-structure checks. Fall back to the most recent slot.
  if(structure.second_structure_time > 0)
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

bool EvaluateStructureTypeFilters(const StrategyContextIndicators &snapshot,
                                  const StrategyStructureLayerContext &ctx)
{
  if(!StructureTypeFiltersRequested(ctx))
    return true;

  StochasticMarketStructure structure;
  if(!FetchStructureForContext(snapshot, structure))
    return false;

  return EvaluateStructureCompoundMode(structure, ctx.structure_compound_filter);
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

  int bar_index = (trigger_mode == LEVELS_AS_LIMITS) ? 1 : 0;
  double close_price = iClose(_Symbol, snapshot.timeframe, bar_index);
  double low_price   = iLow(_Symbol, snapshot.timeframe, bar_index);
  double high_price  = iHigh(_Symbol, snapshot.timeframe, bar_index);

  return ResolveStructureFibonacciEntryForPrices(snapshot.structure_data,
                                                 close_price,
                                                 low_price,
                                                 high_price,
                                                 direction,
                                                 trigger_mode,
                                                 entry_price_out,
                                                 in_zone,
                                                 entry_is_limit);
}

bool ResolveStructureFibonacciEntryForPrices(const StochasticMarketStructure &structure,
                                             const double close_price,
                                             const double low_price,
                                             const double high_price,
                                             const SignalTypes direction,
                                             const StructureTriggerEntryModes trigger_mode,
                                             double &entry_price_out,
                                             bool &in_zone,
                                             bool &entry_is_limit)
{
  entry_price_out = 0.0;
  in_zone = false;
  entry_is_limit = false;

  if(!g_structure_fibo_config.valid)
    return false;

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(structure, peak_price, bottom_price, current_is_bottom))
    return false;

  double close_percent = 0.0;
  double extreme_percent = 0.0;

  if(!ResolveStructurePercentForPrice(peak_price,
                                      bottom_price,
                                      current_is_bottom,
                                      close_price,
                                      close_percent))
    return false;

  if(direction == BULLISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        low_price,
                                        extreme_percent))
      extreme_percent = close_percent;
  }
  else if(direction == BEARISH)
  {
    if(!ResolveStructurePercentForPrice(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        high_price,
                                        extreme_percent))
      extreme_percent = close_percent;
  }
  else
  {
    extreme_percent = close_percent;
  }

  double lower = 0.0;
  double upper = 0.0;
  bool close_ok = ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
                                                        ArraySize(g_structure_fibo_config.levels),
                                                        close_percent,
                                                        lower,
                                                        upper);
  bool close_in = close_ok && (close_percent >= lower && close_percent <= upper);
  bool extreme_in = false;

  if(close_in)
  {
    extreme_in = (extreme_percent >= lower && extreme_percent <= upper);
  }
  else
  {
    double ext_lower = 0.0;
    double ext_upper = 0.0;
    if(ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
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
    if(ResolveStructurePriceForPercent(peak_price,
                                       bottom_price,
                                       current_is_bottom,
                                       lower,
                                       lower_price) &&
       ResolveStructurePriceForPercent(peak_price,
                                       bottom_price,
                                       current_is_bottom,
                                       upper,
                                       upper_price))
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
    double lower_price = 0.0;
    double upper_price = 0.0;
    if(!ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        lower,
                                        lower_price) ||
       !ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        upper,
                                        upper_price))
      return false;

    double min_price = MathMin(lower_price, upper_price);
    double max_price = MathMax(lower_price, upper_price);

    if(direction == BULLISH)
      entry_price_out = min_price;
    else if(direction == BEARISH)
      entry_price_out = max_price;
    else
      entry_price_out = close_price;

    if(direction == BULLISH && entry_price_out > close_price)
      return false;
    if(direction == BEARISH && entry_price_out < close_price)
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

  if(!EvaluateCandleStructureFilter())
  {
    entry_allows = false;
    filters_pass = false;
    return true;
  }

  StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(context);
  if(!EvaluateStructureTypeFilters(snapshot, structure_ctx))
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
