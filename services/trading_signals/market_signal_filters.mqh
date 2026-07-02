//+------------------------------------------------------------------+
//|                              market_signal_filters.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
#define _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_

void ExecutionAppendQueryDebugLog(const string label,
                             const string message);
void ExecutionAppendQueryDebugChangedLog(const string label,
                                    const string state_key,
                                    const string message);

const StructureTriggerEntryModes FOUNDATION_STRUCTURE_TRIGGER_MODE = LEVELS_AS_LIMITS;
const double STRUCTURE_PERCENT_EPS = 0.0001;

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

bool g_structure_limit_terminal_band_guard_runtime_override = false;
bool g_structure_limit_terminal_band_guard_runtime_enabled = false;

int ResolveStructurePercentStepDirection(const SignalTypes direction,
                                         const bool current_is_bottom)
{
  if(direction == BULLISH)
    return current_is_bottom ? 1 : -1;

  if(direction == BEARISH)
    return current_is_bottom ? -1 : 1;

  return 0;
}

bool StructureDirectionMatchesOrientation(const SignalTypes direction,
                                          const bool current_is_bottom)
{
  if(direction == BULLISH)
    return current_is_bottom;
  if(direction == BEARISH)
    return !current_is_bottom;
  return true;
}

string StructureOrientationToken(const bool current_is_bottom)
{
  return current_is_bottom ? "BOTTOM" : "PEAK";
}

void LogStructureDirectionMismatch(const StrategyContextTypes context,
                                   const StructureTriggerEntryModes trigger_mode,
                                   const SignalTypes direction,
                                   const bool current_is_bottom,
                                   const double peak_price,
                                   const double bottom_price,
                                   const double close_price,
                                   const datetime structure_snapshot_time)
{
  string state_key = StringFormat("%s|%s|%s|%d",
                                  EnumToString(context),
                                  EnumToString(direction),
                                  StructureOrientationToken(current_is_bottom),
                                  (int)structure_snapshot_time);
  string message = StringFormat("reason=STRUCTURE_DIRECTION_MISMATCH|context=%s|trigger=%s|dir=%s|orientation=%s|current_is_bottom=%s|peak=%.5f|bottom=%.5f|close=%.5f|structure_ts=%s",
                                EnumToString(context),
                                EnumToString(trigger_mode),
                                EnumToString(direction),
                                StructureOrientationToken(current_is_bottom),
                                current_is_bottom ? "true" : "false",
                                peak_price,
                                bottom_price,
                                close_price,
                                TimeToString(structure_snapshot_time, TIME_DATE|TIME_SECONDS));
  ExecutionAppendQueryDebugChangedLog("SIGNAL_REJECT", state_key, message);
}

void SetStructureLimitTerminalBandGuardRuntime(const bool enabled)
{
  g_structure_limit_terminal_band_guard_runtime_enabled = enabled;
  g_structure_limit_terminal_band_guard_runtime_override = true;
}

void ClearStructureLimitTerminalBandGuardRuntimeOverride()
{
  g_structure_limit_terminal_band_guard_runtime_override = false;
}

bool StructureLimitTerminalBandGuardEnabled(const StructureTriggerEntryModes trigger_mode)
{
  if(trigger_mode != LEVELS_AS_LIMITS)
    return false;

  if(g_structure_limit_terminal_band_guard_runtime_override)
    return g_structure_limit_terminal_band_guard_runtime_enabled;

  return (Base_Strategy_Type == FIB_LEVEL_RANGE &&
          ResolveFoundationLevelStopLimit() == 1 &&
          ResolveFoundationLevelPositionStart() == 0);
}

bool StructureBreakoutLimitAnchoringEnabled(const StrategyContextTypes context,
                                            const StructureTriggerEntryModes trigger_mode)
{
  if(context != CONTEXT_SLOT_BASE)
    return false;
  if(trigger_mode != LEVELS_AS_LIMITS)
    return false;
  return false;
}

StructureTriggerEntryModes ResolveEffectiveStructureTriggerMode(const StrategyContextTypes context,
                                                                const StructureTriggerEntryModes trigger_mode)
{
  if(context != CONTEXT_SLOT_BASE)
    return trigger_mode;
  return trigger_mode;
}

bool ResolveBreakoutLimitBandTarget(const SignalTypes direction,
                                    const double lower_percent,
                                    const double upper_percent,
                                    const double lower_price,
                                    const double upper_price,
                                    double &target_percent_out,
                                    double &target_price_out)
{
  target_percent_out = 0.0;
  target_price_out = 0.0;

  if(direction == BULLISH)
  {
    if(upper_price >= lower_price)
    {
      target_percent_out = upper_percent;
      target_price_out = upper_price;
    }
    else
    {
      target_percent_out = lower_percent;
      target_price_out = lower_price;
    }
    return true;
  }

  if(direction == BEARISH)
  {
    if(upper_price <= lower_price)
    {
      target_percent_out = upper_percent;
      target_price_out = upper_price;
    }
    else
    {
      target_percent_out = lower_percent;
      target_price_out = lower_price;
    }
    return true;
  }

  return false;
}

bool ResolveDirectionalLimitBandTarget(const SignalTypes direction,
                                       const bool current_is_bottom,
                                       const double lower_percent,
                                       const double upper_percent,
                                       const double lower_price,
                                       const double upper_price,
                                       double &target_percent_out,
                                       double &target_price_out)
{
  target_percent_out = 0.0;
  target_price_out = 0.0;

  int step_direction = ResolveStructurePercentStepDirection(direction, current_is_bottom);
  if(step_direction > 0)
  {
    target_percent_out = upper_percent;
    target_price_out = upper_price;
    return true;
  }

  if(step_direction < 0)
  {
    target_percent_out = lower_percent;
    target_price_out = lower_price;
    return true;
  }

  return false;
}

void ResetResolvedFibonacciEntryAnchor(ResolvedFibonacciEntryAnchor &anchor)
{
  anchor.valid   = false;
  anchor.percent = 0.0;
  anchor.price   = 0.0;
}

bool ResolveStructureFibonacciEntryForPricesDetailed(const StochasticMarketStructure &structure,
                                                     const double close_price,
                                                     const double low_price,
                                                     const double high_price,
                                                     const SignalTypes direction,
                                                     const StructureTriggerEntryModes trigger_mode,
                                                     double &entry_price_out,
                                                     bool &in_zone,
                                                     bool &entry_is_limit,
                                                     ResolvedFibonacciEntryAnchor &resolved_entry_out,
                                                     const StrategyContextTypes context = CONTEXT_SLOT_BASE,
                                                     const datetime structure_snapshot_time = 0);

bool StructureLimitEntryRequiresExtrapolatedStopAnchor(const double target_percent,
                                                       const int step_direction)
{
  if(!g_structure_fibo_config.valid || !g_structure_fibo_config.cycle_valid)
    return false;

  int total_levels = ArraySize(g_structure_fibo_config.levels);
  if(total_levels < 2)
    return false;

  double next_percent = 0.0;
  if(!ResolveFibonacciNextPercentCycledWithCycle(g_structure_fibo_config.cycle_levels,
                                                 ArraySize(g_structure_fibo_config.cycle_levels),
                                                 g_structure_fibo_config.cycle_allow_zero,
                                                 target_percent,
                                                 1,
                                                 step_direction,
                                                 next_percent))
    return false;

  double min_level = g_structure_fibo_config.levels[0];
  double max_level = g_structure_fibo_config.levels[total_levels - 1];
  return (next_percent < (min_level - STRUCTURE_PERCENT_EPS) ||
          next_percent > (max_level + STRUCTURE_PERCENT_EPS));
}

int ResolveStructureEntryBarIndex(const StrategyContextTypes context,
                                  const StructureTriggerEntryModes trigger_mode)
{
  if(trigger_mode == LEVELS_AS_LIMITS)
    return 1;

  return 0;
}

bool ResolveStructureFibonacciEntryDetailed(const StrategyContextIndicators &snapshot,
                                            const SignalTypes direction,
                                            const StructureTriggerEntryModes trigger_mode,
                                            double &entry_price_out,
                                            bool &in_zone,
                                            bool &entry_is_limit,
                                            ResolvedFibonacciEntryAnchor &resolved_entry_out)
{
  entry_price_out = 0.0;
  in_zone = false;
  entry_is_limit = false;
  ResetResolvedFibonacciEntryAnchor(resolved_entry_out);

  if(!snapshot.structure_valid)
    return false;
  if(!g_structure_fibo_config.valid)
    return false;

  StructureTriggerEntryModes effective_trigger_mode = ResolveEffectiveStructureTriggerMode(snapshot.context,
                                                                                            trigger_mode);
  int bar_index = ResolveStructureEntryBarIndex(snapshot.context, effective_trigger_mode);
  if(Bars(_Symbol, snapshot.timeframe) <= bar_index)
    return false;

  double close_price = iClose(_Symbol, snapshot.timeframe, bar_index);
  double low_price   = iLow(_Symbol, snapshot.timeframe, bar_index);
  double high_price  = iHigh(_Symbol, snapshot.timeframe, bar_index);

  StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(snapshot.context);
  datetime structure_snapshot_time = ResolveStructureSnapshotTimestamp(snapshot.structure_data, structure_ctx);

  return ResolveStructureFibonacciEntryForPricesDetailed(snapshot.structure_data,
                                                         close_price,
                                                         low_price,
                                                         high_price,
                                                         direction,
                                                         effective_trigger_mode,
                                                         entry_price_out,
                                                         in_zone,
                                                         entry_is_limit,
                                                         resolved_entry_out,
                                                         snapshot.context,
                                                         structure_snapshot_time);
}

bool ResolveStructureFibonacciEntry(const StrategyContextIndicators &snapshot,
                                    const SignalTypes direction,
                                    const StructureTriggerEntryModes trigger_mode,
                                    double &entry_price_out,
                                    bool &in_zone,
                                    bool &entry_is_limit)
{
  ResolvedFibonacciEntryAnchor resolved_entry;
  return ResolveStructureFibonacciEntryDetailed(snapshot,
                                                direction,
                                                trigger_mode,
                                                entry_price_out,
                                                in_zone,
                                                entry_is_limit,
                                                resolved_entry);
}

bool ResolveStructureFibonacciEntryForPricesDetailed(const StochasticMarketStructure &structure,
                                                     const double close_price,
                                                     const double low_price,
                                                     const double high_price,
                                                     const SignalTypes direction,
                                                     const StructureTriggerEntryModes trigger_mode,
                                                     double &entry_price_out,
                                                     bool &in_zone,
                                                     bool &entry_is_limit,
                                                     ResolvedFibonacciEntryAnchor &resolved_entry_out,
                                                     const StrategyContextTypes context,
                                                     const datetime structure_snapshot_time)
{
  entry_price_out = 0.0;
  in_zone = false;
  entry_is_limit = false;
  ResetResolvedFibonacciEntryAnchor(resolved_entry_out);
  StructureTriggerEntryModes effective_trigger_mode = ResolveEffectiveStructureTriggerMode(context,
                                                                                            trigger_mode);

  if(!g_structure_fibo_config.valid)
    return false;

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureReferenceRange(structure, peak_price, bottom_price, current_is_bottom))
    return false;

  if(!StructureDirectionMatchesOrientation(direction, current_is_bottom))
  {
    LogStructureDirectionMismatch(context,
                                  effective_trigger_mode,
                                  direction,
                                  current_is_bottom,
                                  peak_price,
                                  bottom_price,
                                  close_price,
                                  structure_snapshot_time);
    return true;
  }

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

  double close_lower = 0.0;
  double close_upper = 0.0;
  double extreme_lower = 0.0;
  double extreme_upper = 0.0;

  bool close_ok = ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
                                                        ArraySize(g_structure_fibo_config.levels),
                                                        close_percent,
                                                        close_lower,
                                                        close_upper);
  bool close_in = close_ok && (close_percent >= close_lower && close_percent <= close_upper);

  bool extreme_ok = ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
                                                           ArraySize(g_structure_fibo_config.levels),
                                                           extreme_percent,
                                                           extreme_lower,
                                                           extreme_upper);
  bool extreme_in = extreme_ok && (extreme_percent >= extreme_lower && extreme_percent <= extreme_upper);

  double lower = 0.0;
  double upper = 0.0;
  if(close_in)
  {
    lower = close_lower;
    upper = close_upper;
  }
  else if(extreme_in)
  {
    lower = extreme_lower;
    upper = extreme_upper;
  }

  bool breakout_limit_mode = StructureBreakoutLimitAnchoringEnabled(context, effective_trigger_mode);
  int step_direction = ResolveStructurePercentStepDirection(direction, current_is_bottom);
  if(step_direction == 0)
    step_direction = 1;

  if(!close_in && !extreme_in)
    return true; // no trigger but not fatal

  if(StructureLimitTerminalBandGuardEnabled(effective_trigger_mode) &&
     !breakout_limit_mode)
  {
    double target_percent = (step_direction > 0) ? upper : lower;
    if(StructureLimitEntryRequiresExtrapolatedStopAnchor(target_percent, step_direction))
      return true;
  }

  double required_points = EnforceBrokerDistance(g_symbol_constraints, Points_Range_Setup);
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
      double point_size = ExecutionResolvePointSizeSafe();
      double range_points = (point_size > 0.0)
                              ? MathAbs(lower_price - upper_price) / point_size
                              : 0.0;
      if(range_points < required_points)
        return true; // range too tight, skip entry
    }
  }

  in_zone = true;
  entry_is_limit = (effective_trigger_mode == LEVELS_AS_LIMITS);

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

    if(breakout_limit_mode)
    {
      double entry_percent = 0.0;
      if(!ResolveBreakoutLimitBandTarget(direction,
                                         lower,
                                         upper,
                                         lower_price,
                                         upper_price,
                                         entry_percent,
                                         entry_price_out))
        return false;

      resolved_entry_out.valid   = true;
      resolved_entry_out.percent = entry_percent;
      resolved_entry_out.price   = entry_price_out;
    }
    else
    {
      double entry_percent = 0.0;
      if(!ResolveDirectionalLimitBandTarget(direction,
                                            current_is_bottom,
                                            lower,
                                            upper,
                                            lower_price,
                                            upper_price,
                                            entry_percent,
                                            entry_price_out))
        entry_price_out = close_price;
      else
      {
        resolved_entry_out.valid   = true;
        resolved_entry_out.percent = entry_percent;
        resolved_entry_out.price   = entry_price_out;
      }

      if(direction == BULLISH && entry_price_out > close_price)
        return false;
      if(direction == BEARISH && entry_price_out < close_price)
        return false;
    }
  }
  else
  {
    entry_price_out = close_price; // market execution at current close
  }

  return true;
}

bool ResolveStructureFibonacciEntryForPrices(const StochasticMarketStructure &structure,
                                             const double close_price,
                                             const double low_price,
                                             const double high_price,
                                             const SignalTypes direction,
                                             const StructureTriggerEntryModes trigger_mode,
                                             double &entry_price_out,
                                             bool &in_zone,
                                             bool &entry_is_limit,
                                             const StrategyContextTypes context = CONTEXT_SLOT_BASE,
                                             const datetime structure_snapshot_time = 0)
{
  ResolvedFibonacciEntryAnchor resolved_entry;
  return ResolveStructureFibonacciEntryForPricesDetailed(structure,
                                                         close_price,
                                                         low_price,
                                                         high_price,
                                                         direction,
                                                         trigger_mode,
                                                         entry_price_out,
                                                         in_zone,
                                                         entry_is_limit,
                                                         resolved_entry,
                                                         context,
                                                         structure_snapshot_time);
}

bool StrategyContextEvaluateEntryDetailed(const StrategyContextIndicators &snapshot,
                                          const SignalTypes direction,
                                          datetime &structure_capture_time,
                                          bool &entry_allows,
                                          bool &filters_pass,
                                          double &entry_price_out,
                                          bool &entry_is_limit,
                                          ResolvedFibonacciEntryAnchor &resolved_entry_out)
{
  structure_capture_time = 0;
  entry_allows = false;
  filters_pass = true;
  entry_price_out = 0.0;
  entry_is_limit = false;
  ResetResolvedFibonacciEntryAnchor(resolved_entry_out);

  StrategyContextTypes context = snapshot.context;

  StrategyStructureLayerContext structure_ctx = BuildStructureLayerForContext(context);
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
  if(!ResolveStructureFibonacciEntryDetailed(snapshot,
                                             direction,
                                             FOUNDATION_STRUCTURE_TRIGGER_MODE,
                                             entry_price,
                                             in_zone,
                                             resolved_is_limit,
                                             resolved_entry_out))
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

bool StrategyContextEvaluateEntry(const StrategyContextIndicators &snapshot,
                                  const SignalTypes direction,
                                  datetime &structure_capture_time,
                                  bool &entry_allows,
                                  bool &filters_pass,
                                  double &entry_price_out,
                                  bool &entry_is_limit)
{
  ResolvedFibonacciEntryAnchor resolved_entry;
  return StrategyContextEvaluateEntryDetailed(snapshot,
                                              direction,
                                              structure_capture_time,
                                              entry_allows,
                                              filters_pass,
                                              entry_price_out,
                                              entry_is_limit,
                                              resolved_entry);
}

#endif // _SERVICES_TRADING_SIGNALS_MARKET_SIGNAL_FILTERS_MQH_
