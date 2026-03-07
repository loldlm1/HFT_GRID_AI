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

const double STRUCTURE_TOUCH_POLICY_EPS = 0.0001;

struct StructureTouchProgressRuntime
{
  StrategyContextTypes context;
  SignalTypes          direction;
  datetime             structure_time;
  int                  step_direction;
  bool                 initialized;
  double               progress_percent;

  StructureTouchProgressRuntime()
  {
    context          = CONTEXT_SLOT_BASE;
    direction        = NO_SIGNAL;
    structure_time   = 0;
    step_direction   = 1;
    initialized      = false;
    progress_percent = 0.0;
  }
};

StructureTouchProgressRuntime g_structure_touch_progress_state[];
bool g_structure_limit_terminal_band_guard_runtime_override = false;
bool g_structure_limit_terminal_band_guard_runtime_enabled = false;

void ClearStructureTouchPolicyState()
{
  ArrayResize(g_structure_touch_progress_state, 0);
}

datetime ResolveStructureTouchPolicyStructureTime(const StochasticMarketStructure &structure,
                                                  const datetime fallback_time)
{
  if(fallback_time > 0)
    return fallback_time;

  if(structure.second_structure_time > 0)
    return structure.second_structure_time;

  return structure.first_structure_time;
}

int ResolveStructurePercentStepDirection(const SignalTypes direction,
                                         const bool current_is_bottom)
{
  if(direction == BULLISH)
    return current_is_bottom ? 1 : -1;

  if(direction == BEARISH)
    return current_is_bottom ? -1 : 1;

  return 0;
}

int FindStructureTouchProgressSlot(const StrategyContextTypes context,
                                   const SignalTypes direction)
{
  int total = ArraySize(g_structure_touch_progress_state);
  for(int i = 0; i < total; i++)
  {
    StructureTouchProgressRuntime slot = g_structure_touch_progress_state[i];
    if(slot.context == context && slot.direction == direction)
      return i;
  }
  return -1;
}

bool EnsureStructureTouchProgressSlot(const StrategyContextTypes context,
                                      const SignalTypes direction,
                                      int &slot_index)
{
  slot_index = FindStructureTouchProgressSlot(context, direction);
  if(slot_index >= 0)
    return true;

  StructureTouchProgressRuntime created;
  created.context = context;
  created.direction = direction;
  int next = ArraySize(g_structure_touch_progress_state);
  ArrayResize(g_structure_touch_progress_state, next + 1);
  g_structure_touch_progress_state[next] = created;
  slot_index = next;
  return true;
}

bool ResolveStructureTouchProgressBefore(const StrategyContextTypes context,
                                         const SignalTypes direction,
                                         const datetime structure_time,
                                         const int step_direction,
                                         double &progress_before,
                                         bool &has_progress)
{
  progress_before = 0.0;
  has_progress = false;

  if(structure_time <= 0)
    return true;

  int slot_index = -1;
  if(!EnsureStructureTouchProgressSlot(context, direction, slot_index))
    return false;

  StructureTouchProgressRuntime slot = g_structure_touch_progress_state[slot_index];
  if(!slot.initialized ||
     slot.structure_time != structure_time ||
     slot.step_direction != step_direction)
    return true;

  progress_before = slot.progress_percent;
  has_progress = true;
  return true;
}

bool CommitStructureTouchProgress(const StrategyContextTypes context,
                                  const SignalTypes direction,
                                  const datetime structure_time,
                                  const int step_direction,
                                  const double percent_value)
{
  if(structure_time <= 0 || !MathIsValidNumber(percent_value))
    return true;

  int slot_index = -1;
  if(!EnsureStructureTouchProgressSlot(context, direction, slot_index))
    return false;

  StructureTouchProgressRuntime slot = g_structure_touch_progress_state[slot_index];

  if(!slot.initialized ||
     slot.structure_time != structure_time ||
     slot.step_direction != step_direction)
  {
    slot.structure_time   = structure_time;
    slot.step_direction   = step_direction;
    slot.progress_percent = percent_value;
    slot.initialized      = true;
    g_structure_touch_progress_state[slot_index] = slot;
    return true;
  }

  if(step_direction >= 0)
  {
    if(percent_value > slot.progress_percent)
      slot.progress_percent = percent_value;
  }
  else
  {
    if(percent_value < slot.progress_percent)
      slot.progress_percent = percent_value;
  }

  g_structure_touch_progress_state[slot_index] = slot;
  return true;
}

bool PercentReachedTargetForStep(const double progress_percent,
                                 const double target_percent,
                                 const int step_direction)
{
  if(step_direction >= 0)
    return (progress_percent + STRUCTURE_TOUCH_POLICY_EPS >= target_percent);

  return (progress_percent - STRUCTURE_TOUCH_POLICY_EPS <= target_percent);
}

bool PercentReachedBandForStep(const double progress_percent,
                               const double lower_percent,
                               const double upper_percent,
                               const int step_direction)
{
  if(step_direction >= 0)
    return (progress_percent + STRUCTURE_TOUCH_POLICY_EPS >= lower_percent);

  return (progress_percent - STRUCTURE_TOUCH_POLICY_EPS <= upper_percent);
}

bool FibonacciRangeEquals(const double first_lower,
                          const double first_upper,
                          const double second_lower,
                          const double second_upper)
{
  return (MathAbs(first_lower - second_lower) <= STRUCTURE_TOUCH_POLICY_EPS) &&
         (MathAbs(first_upper - second_upper) <= STRUCTURE_TOUCH_POLICY_EPS);
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
          Grid_Level_Stop_Limit == 1 &&
          Grid_Level_Position_Start == 0);
}

bool StructureBreakoutLimitAnchoringEnabled(const StrategyContextTypes context,
                                            const StructureTriggerEntryModes trigger_mode)
{
  if(trigger_mode != LEVELS_AS_LIMITS)
    return false;

  if(!StrategyContextUsesBreakoutCompoundMode(context))
    return false;

  return g_structure_fibo_config.valid;
}

StructureTriggerEntryModes ResolveEffectiveStructureTriggerMode(const StrategyContextTypes context,
                                                                const StructureTriggerEntryModes trigger_mode)
{
  if(trigger_mode == LEVEL_AS_ZONE && StrategyContextUsesBreakoutCompoundMode(context))
    return LEVELS_AS_LIMITS;

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
  return (next_percent < (min_level - STRUCTURE_TOUCH_POLICY_EPS) ||
          next_percent > (max_level + STRUCTURE_TOUCH_POLICY_EPS));
}

int ResolveStructureEntryBarIndex(const StrategyContextTypes context,
                                  const StructureTriggerEntryModes trigger_mode)
{
  if(trigger_mode == LEVELS_AS_LIMITS)
    return 1;

  if(trigger_mode == LEVEL_AS_ZONE && StrategyContextFirstTouchOnly(context))
    return 1;

  return 0;
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

  return ResolveStructureFibonacciEntryForPrices(snapshot.structure_data,
                                                 close_price,
                                                 low_price,
                                                 high_price,
                                                 direction,
                                                 effective_trigger_mode,
                                                 entry_price_out,
                                                 in_zone,
                                                 entry_is_limit,
                                                 snapshot.context,
                                                 structure_snapshot_time);
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
  entry_price_out = 0.0;
  in_zone = false;
  entry_is_limit = false;
  StructureTriggerEntryModes effective_trigger_mode = ResolveEffectiveStructureTriggerMode(context,
                                                                                            trigger_mode);

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

  StructureTouchPolicyModes touch_policy = StrategyContextTouchPolicy(context);
  bool first_touch_only = (touch_policy == FIRST_TOUCH_ONLY);
  bool enforce_first_touch_only = first_touch_only && !breakout_limit_mode;
  int step_direction = ResolveStructurePercentStepDirection(direction, current_is_bottom);
  if(step_direction == 0)
    step_direction = 1;

  datetime resolved_structure_time = ResolveStructureTouchPolicyStructureTime(structure,
                                                                              structure_snapshot_time);
  if(enforce_first_touch_only && resolved_structure_time <= 0)
    return false;

  if(enforce_first_touch_only)
  {
    if(effective_trigger_mode == LEVELS_AS_LIMITS)
    {
      if(!close_in && !extreme_in)
      {
        if(!CommitStructureTouchProgress(context,
                                         direction,
                                         resolved_structure_time,
                                         step_direction,
                                         extreme_percent))
          return false;
        return true;
      }

      double target_percent = (step_direction > 0) ? upper : lower;
      if(breakout_limit_mode)
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

        double target_price = 0.0;
        if(!ResolveBreakoutLimitBandTarget(direction,
                                           lower,
                                           upper,
                                           lower_price,
                                           upper_price,
                                           target_percent,
                                           target_price))
          return false;
      }
      double progress_before = 0.0;
      bool has_progress_before = false;
      if(!ResolveStructureTouchProgressBefore(context,
                                              direction,
                                              resolved_structure_time,
                                              step_direction,
                                              progress_before,
                                              has_progress_before))
        return false;

      bool touched_before = has_progress_before &&
                            PercentReachedTargetForStep(progress_before,
                                                        target_percent,
                                                        step_direction);
      bool touches_now = PercentReachedTargetForStep(extreme_percent,
                                                     target_percent,
                                                     step_direction);

      if(!CommitStructureTouchProgress(context,
                                       direction,
                                       resolved_structure_time,
                                       step_direction,
                                       extreme_percent))
        return false;

      if(touched_before || touches_now)
        return true;
    }
    else if(effective_trigger_mode == LEVEL_AS_ZONE)
    {
      if(!close_in || !extreme_in)
      {
        if(!CommitStructureTouchProgress(context,
                                         direction,
                                         resolved_structure_time,
                                         step_direction,
                                         extreme_percent))
          return false;
        return true;
      }

      if(!FibonacciRangeEquals(close_lower,
                               close_upper,
                               extreme_lower,
                               extreme_upper))
      {
        if(!CommitStructureTouchProgress(context,
                                         direction,
                                         resolved_structure_time,
                                         step_direction,
                                         extreme_percent))
          return false;
        return true;
      }

      double progress_before = 0.0;
      bool has_progress_before = false;
      if(!ResolveStructureTouchProgressBefore(context,
                                              direction,
                                              resolved_structure_time,
                                              step_direction,
                                              progress_before,
                                              has_progress_before))
        return false;

      bool touched_before = has_progress_before &&
                            PercentReachedBandForStep(progress_before,
                                                      close_lower,
                                                      close_upper,
                                                      step_direction);

      if(!CommitStructureTouchProgress(context,
                                       direction,
                                       resolved_structure_time,
                                       step_direction,
                                       extreme_percent))
        return false;

      if(touched_before)
        return true;

      lower = close_lower;
      upper = close_upper;
    }
  }

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
      double point_size = GridResolvePointSizeSafe();
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
    }
    else
    {
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
