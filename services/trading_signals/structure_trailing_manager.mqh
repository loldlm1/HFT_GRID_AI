//+------------------------------------------------------------------+
//|                 trading_signals/structure_trailing_manager.mqh   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_STRUCTURE_TRAILING_MANAGER_MQH_
#define _SERVICES_TRADING_SIGNALS_STRUCTURE_TRAILING_MANAGER_MQH_

struct TrailingStructureCache
{
  bool                 loaded;
  ENUM_TIMEFRAMES      timeframe;
  datetime             bar_time;
  datetime             snapshot_time;
  StochasticMarketStructure structure;

  TrailingStructureCache()
  {
    loaded        = false;
    timeframe     = PERIOD_CURRENT;
    bar_time      = 0;
    snapshot_time = 0;
  }
};

TrailingStructureCache g_trailing_structure_caches[4];

double TrailingPriceCompareEpsilon()
{
  double point_size = GridResolvePointSize();
  if(point_size <= 0.0)
    return 0.0000001;

  return point_size * 0.1;
}

ENUM_TIMEFRAMES ResolveSignalStructureTimeframe(const SignalParams &signal_params)
{
  if(signal_params.strategy_timeframe != PERIOD_CURRENT)
    return signal_params.strategy_timeframe;

  if(Strategy_Timeframe != PERIOD_CURRENT)
    return Strategy_Timeframe;

  return PERIOD_M1;
}

bool ResolveSignalCurrentActiveOrderIndex(const SignalParams &signal_params,
                                          int &active_index_out)
{
  active_index_out = -1;

  int total_levels = ArraySize(signal_params.grid_orders);
  for(int idx = total_levels - 1; idx >= 0; idx--)
  {
    GridOrderState state = signal_params.grid_orders[idx];
    if(!state.opens_position)
      continue;
    if(state.status != GRID_ORDER_ACTIVE)
      continue;
    if(state.lot_size <= 0.0)
      continue;

    active_index_out = idx;
    return true;
  }

  return false;
}

double CalculateSignalRemainingOpenVolume(const SignalParams &signal_params)
{
  double remaining_volume = 0.0;
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int idx = 0; idx < total_levels; idx++)
  {
    GridOrderState state = signal_params.grid_orders[idx];
    if(!state.opens_position)
      continue;
    if(state.status != GRID_ORDER_ACTIVE)
      continue;
    if(state.lot_size <= 0.0)
      continue;

    remaining_volume += state.lot_size;
  }

  return remaining_volume;
}

void RefreshSignalExposureState(SignalParams &signal_params)
{
  signal_params.remaining_open_volume = CalculateSignalRemainingOpenVolume(signal_params);
  if(signal_params.remaining_open_volume <= 0.0)
  {
    signal_params.trailing_partial_slice_volume = 0.0;
    return;
  }

  if(signal_params.trailing_reference_total_volume <= 0.0 ||
     signal_params.remaining_open_volume > signal_params.trailing_reference_total_volume)
  {
    signal_params.trailing_reference_total_volume = signal_params.remaining_open_volume;
  }

  double close_percent = ResolveTrailingTpClosePercent();
  if(close_percent <= 0.0)
  {
    signal_params.trailing_partial_slice_volume = 0.0;
    return;
  }

  double requested_slice = signal_params.trailing_reference_total_volume * (close_percent / 100.0);
  signal_params.trailing_partial_slice_volume = NormalizeVolumeForSymbol(_Symbol, requested_slice);
}

bool ResolveTrailingStructureSnapshot(const SignalParams &signal_params,
                                      StochasticMarketStructure &structure_out,
                                      datetime &snapshot_time_out)
{
  structure_out = StochasticMarketStructure();
  snapshot_time_out = 0;

  ENUM_TIMEFRAMES tf = ResolveSignalStructureTimeframe(signal_params);
  datetime current_bar_time = iTime(_Symbol, tf, 0);
  int cache_slot = (int)signal_params.strategy_context;

  if(cache_slot >= 0 && cache_slot < 4)
  {
    TrailingStructureCache cache = g_trailing_structure_caches[cache_slot];
    if(cache.loaded &&
       cache.timeframe == tf &&
       cache.bar_time == current_bar_time &&
       cache.snapshot_time > 0)
    {
      structure_out = cache.structure;
      snapshot_time_out = cache.snapshot_time;
      return true;
    }
  }

  if(!LoadStructureSnapshotForTimeframe(tf, structure_out))
    return false;

  if(!ResolveStructureSnapshotTimeForContext(signal_params.strategy_context,
                                             structure_out,
                                             snapshot_time_out))
  {
    snapshot_time_out = 0;
  }

  if(cache_slot >= 0 && cache_slot < 4)
  {
    g_trailing_structure_caches[cache_slot].loaded = true;
    g_trailing_structure_caches[cache_slot].timeframe = tf;
    g_trailing_structure_caches[cache_slot].bar_time = current_bar_time;
    g_trailing_structure_caches[cache_slot].snapshot_time = snapshot_time_out;
    g_trailing_structure_caches[cache_slot].structure = structure_out;
  }

  return true;
}

bool TrailingExtremumMatchesTarget(const SignalTypes direction,
                                   const bool for_stop,
                                   const OscillatorMarketStructure &extremum)
{
  if(direction == BULLISH)
    return for_stop ? !extremum.is_peak : extremum.is_peak;

  if(direction == BEARISH)
    return for_stop ? extremum.is_peak : !extremum.is_peak;

  return false;
}

double ResolveTrailingExtremumPrice(const SignalTypes direction,
                                    const bool for_stop,
                                    const OscillatorMarketStructure &extremum)
{
  if(direction == BULLISH)
    return for_stop ? extremum.extremum_low : extremum.extremum_high;

  if(direction == BEARISH)
    return for_stop ? extremum.extremum_high : extremum.extremum_low;

  return 0.0;
}

bool TrailingPriceImprovesDirectionally(const SignalParams &signal_params,
                                        const bool for_stop,
                                        const double candidate_price)
{
  double epsilon = TrailingPriceCompareEpsilon();
  double reference_price = 0.0;

  if(for_stop)
    reference_price = signal_params.trailing_last_sl_price;
  else
    reference_price = signal_params.trailing_last_tp_price;

  if(reference_price <= 0.0)
    return true;

  if(signal_params.signal_type == BULLISH)
    return (candidate_price > reference_price + epsilon);

  if(signal_params.signal_type == BEARISH)
    return (candidate_price < reference_price - epsilon);

  return false;
}

datetime ResolveTrailingCandidateEligibilityTime(const SignalParams &signal_params,
                                                 const bool for_stop)
{
  datetime eligible_after_time = for_stop
                                 ? signal_params.trailing_last_sl_structure_time
                                 : signal_params.trailing_last_tp_structure_time;

  int active_level_index = -1;
  if(!ResolveSignalCurrentActiveOrderIndex(signal_params, active_level_index))
    return eligible_after_time;

  if(active_level_index < 0 || active_level_index >= ArraySize(signal_params.grid_orders))
    return eligible_after_time;

  // Both stop and TP trailing must wait for a structure formed after the
  // currently active level went live, otherwise the EA can reuse stale
  // pre-activation extrema on the same tick the level becomes active.
  datetime level_activation_time = signal_params.grid_orders[active_level_index].last_action_time;
  if(level_activation_time > eligible_after_time)
    eligible_after_time = level_activation_time;

  return eligible_after_time;
}

bool FindNextTrailingCandidate(const SignalParams &signal_params,
                               const StochasticMarketStructure &structure,
                               const bool for_stop,
                               double &price_out,
                               datetime &time_out)
{
  price_out = 0.0;
  time_out = 0;

  datetime eligible_after_time = ResolveTrailingCandidateEligibilityTime(signal_params,
                                                                         for_stop);

  int total = ArraySize(structure.os_market_structures);
  for(int idx = 1; idx < total; idx++)
  {
    OscillatorMarketStructure extremum = structure.os_market_structures[idx];
    if(!TrailingExtremumMatchesTarget(signal_params.signal_type, for_stop, extremum))
      continue;
    if(extremum.extremum_time <= 0)
      continue;
    if(eligible_after_time > 0 && extremum.extremum_time <= eligible_after_time)
      continue;

    double candidate_price = ResolveTrailingExtremumPrice(signal_params.signal_type,
                                                          for_stop,
                                                          extremum);
    if(candidate_price <= 0.0)
      continue;
    if(!TrailingPriceImprovesDirectionally(signal_params, for_stop, candidate_price))
      continue;

    price_out = candidate_price;
    time_out = extremum.extremum_time;
    return true;
  }

  return false;
}

bool ResolveTrailingTpAnchorForSignal(const SignalParams &signal_params,
                                      const int active_level_index,
                                      double &anchor_price_out)
{
  anchor_price_out = 0.0;

  if(active_level_index > 0 &&
     active_level_index < ArraySize(signal_params.grid_orders))
  {
    double level_anchor = signal_params.grid_orders[active_level_index].initial_take_profit_price;
    if(level_anchor > 0.0)
    {
      anchor_price_out = level_anchor;
      return true;
    }
  }

  if(signal_params.trailing_first_level_take_profit_price > 0.0)
  {
    anchor_price_out = signal_params.trailing_first_level_take_profit_price;
    return true;
  }

  if(active_level_index >= 0 &&
     active_level_index < ArraySize(signal_params.grid_orders))
  {
    double fallback_anchor = signal_params.grid_orders[active_level_index].initial_take_profit_price;
    if(fallback_anchor > 0.0)
    {
      anchor_price_out = fallback_anchor;
      return true;
    }
  }

  return false;
}

double ResolveNetBreakEvenForSignalAtPrice(const SignalParams &signal_params,
                                           const double close_price)
{
  double net_profit = signal_params.realized_profit;
  net_profit += ResolveProjectedBasketProfitAtPrice(signal_params, close_price);
  return net_profit;
}

double ResolveDirectionalPnLProxyForSignalAtPrice(const SignalParams &signal_params,
                                                  const double close_price)
{
  double proxy = 0.0;
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int idx = 0; idx < total_levels; idx++)
  {
    GridOrderState state = signal_params.grid_orders[idx];
    if(!state.opens_position)
      continue;
    if(state.status != GRID_ORDER_ACTIVE)
      continue;
    if(state.lot_size <= 0.0)
      continue;

    double entry_price = state.entry_price;
    if(entry_price <= 0.0)
      entry_price = state.entry_reference_price;
    if(entry_price <= 0.0)
      continue;

    if(signal_params.signal_type == BULLISH)
      proxy += (close_price - entry_price) * state.lot_size;
    else if(signal_params.signal_type == BEARISH)
      proxy += (entry_price - close_price) * state.lot_size;
  }

  return proxy;
}

bool CanAdvanceTrailingStopToBreakEven(const SignalParams &signal_params,
                                       const double candidate_price)
{
  double net_profit = ResolveNetBreakEvenForSignalAtPrice(signal_params, candidate_price);
  if(net_profit < -0.0000001)
    return false;
  if(net_profit > 0.0000001)
    return true;

  // Fallback: if projected currency profit resolves to neutral because the
  // terminal cannot provide point-value math, keep the sign check directional.
  if(MathAbs(signal_params.realized_profit) <= 0.0000001)
  {
    double proxy = ResolveDirectionalPnLProxyForSignalAtPrice(signal_params,
                                                              candidate_price);
    if(proxy < -0.0000001)
      return false;
  }

  return true;
}

bool CanAdvanceTrailingTpBeyondInitialTarget(const SignalParams &signal_params,
                                             const int active_level_index,
                                             const double candidate_price)
{
  double anchor_price = 0.0;
  if(!ResolveTrailingTpAnchorForSignal(signal_params, active_level_index, anchor_price))
    return true;

  double epsilon = TrailingPriceCompareEpsilon();
  if(signal_params.signal_type == BULLISH)
    return (candidate_price >= anchor_price - epsilon);

  if(signal_params.signal_type == BEARISH)
    return (candidate_price <= anchor_price + epsilon);

  return true;
}

bool ApplyTrailingModeRules(const SignalParams &signal_params,
                            const int active_level_index,
                            const bool for_stop,
                            const double candidate_price)
{
  TrailingStructureModes mode = ResolveTrailingStructureMode();
  if(mode == TRAILING_OFF)
    return false;

  if(mode == TRAILING_BY_STRUCTURE)
    return true;

  if(mode != TRAILING_BY_STRUCTURE_TP_BE)
    return true;

  if(for_stop)
    return CanAdvanceTrailingStopToBreakEven(signal_params, candidate_price);

  return CanAdvanceTrailingTpBeyondInitialTarget(signal_params,
                                                 active_level_index,
                                                 candidate_price);
}

double ResolveSignalRequestedPartialCloseVolume(const SignalParams &signal_params)
{
  if(!StructureTrailingTpCloseEnabled())
    return 0.0;

  double remaining_volume = signal_params.remaining_open_volume;
  if(remaining_volume <= 0.0)
    return 0.0;

  double slice_volume = signal_params.trailing_partial_slice_volume;
  if(slice_volume <= 0.0)
  {
    double close_percent = ResolveTrailingTpClosePercent();
    if(close_percent <= 0.0)
      return 0.0;

    slice_volume = signal_params.trailing_reference_total_volume * (close_percent / 100.0);
  }

  double normalized_slice = NormalizeVolumeForSymbol(_Symbol, slice_volume);
  if(normalized_slice <= 0.0)
    normalized_slice = remaining_volume;

  if(normalized_slice >= remaining_volume - 0.0000001)
    return remaining_volume;

  return normalized_slice;
}

bool ResolveSignalTrailingTargets(SignalParams &signal_params,
                                  double &stop_price_out,
                                  datetime &stop_time_out,
                                  bool &has_stop_update_out,
                                  double &tp_price_out,
                                  datetime &tp_time_out,
                                  bool &has_tp_update_out)
{
  stop_price_out = 0.0;
  stop_time_out = 0;
  has_stop_update_out = false;
  tp_price_out = 0.0;
  tp_time_out = 0;
  has_tp_update_out = false;

  if(!StructureTrailingEnabled())
    return false;

  int active_level_index = -1;
  if(!ResolveSignalCurrentActiveOrderIndex(signal_params, active_level_index))
    return false;

  signal_params.trailing_active_level_index = active_level_index;
  RefreshSignalExposureState(signal_params);

  if(active_level_index == 0 &&
     signal_params.trailing_first_level_take_profit_price <= 0.0 &&
     ArraySize(signal_params.grid_orders) > 0)
  {
    signal_params.trailing_first_level_take_profit_price =
      signal_params.grid_orders[0].initial_take_profit_price;
  }

  StochasticMarketStructure structure;
  datetime snapshot_time = 0;
  if(!ResolveTrailingStructureSnapshot(signal_params, structure, snapshot_time))
    return false;

  double candidate_stop = 0.0;
  datetime candidate_stop_time = 0;
  if(FindNextTrailingCandidate(signal_params,
                               structure,
                               true,
                               candidate_stop,
                               candidate_stop_time) &&
     ApplyTrailingModeRules(signal_params,
                            active_level_index,
                            true,
                            candidate_stop))
  {
    stop_price_out = candidate_stop;
    stop_time_out = candidate_stop_time;
    has_stop_update_out = true;
  }

  double candidate_tp = 0.0;
  datetime candidate_tp_time = 0;
  if(FindNextTrailingCandidate(signal_params,
                               structure,
                               false,
                               candidate_tp,
                               candidate_tp_time) &&
     ApplyTrailingModeRules(signal_params,
                            active_level_index,
                            false,
                            candidate_tp))
  {
    tp_price_out = candidate_tp;
    tp_time_out = candidate_tp_time;
    has_tp_update_out = true;
  }

  return true;
}

void ApplySignalTrailingTargetUpdates(SignalParams &signal_params,
                                      const double stop_price,
                                      const datetime stop_time,
                                      const bool has_stop_update,
                                      const double tp_price,
                                      const datetime tp_time,
                                      const bool has_tp_update)
{
  if(has_stop_update && stop_price > 0.0 && stop_time > 0)
  {
    signal_params.trailing_stop_price = stop_price;
    signal_params.trailing_last_sl_price = stop_price;
    signal_params.trailing_last_sl_structure_time = stop_time;
  }

  if(has_tp_update && tp_price > 0.0 && tp_time > 0)
  {
    signal_params.trailing_take_profit_price = tp_price;
    signal_params.trailing_last_tp_price = tp_price;
    signal_params.trailing_last_tp_structure_time = tp_time;
  }
}

bool SignalTrailingStopHit(const SignalParams &signal_params)
{
  if(signal_params.trailing_stop_price <= 0.0)
    return false;

  double current_price = GridCurrentPriceForDirection(signal_params.signal_type, false);
  if(signal_params.signal_type == BULLISH)
    return (current_price <= signal_params.trailing_stop_price);

  if(signal_params.signal_type == BEARISH)
    return (current_price >= signal_params.trailing_stop_price);

  return false;
}

bool SignalTrailingTakeProfitHit(const SignalParams &signal_params)
{
  if(signal_params.trailing_take_profit_price <= 0.0)
    return false;

  double current_price = GridCurrentPriceForDirection(signal_params.signal_type, false);
  if(signal_params.signal_type == BULLISH)
    return (current_price >= signal_params.trailing_take_profit_price);

  if(signal_params.signal_type == BEARISH)
    return (current_price <= signal_params.trailing_take_profit_price);

  return false;
}

void ClearSignalTrailingTakeProfit(SignalParams &signal_params)
{
  signal_params.trailing_take_profit_price = 0.0;
}

#endif // _SERVICES_TRADING_SIGNALS_STRUCTURE_TRAILING_MANAGER_MQH_
