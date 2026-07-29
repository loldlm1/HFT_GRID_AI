//+------------------------------------------------------------------+
//|                               microservices/trading_signals/... |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LEG_HELPERS_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LEG_HELPERS_MQH_

const double FOUNDATION_LEVEL_EXPONENTIAL_MULTIPLIER = 1.0;
const int FOUNDATION_LEVEL_POSITION_START = 0;
const int FOUNDATION_LEVEL_STOP_LIMIT = 1;
const int    PARTIAL_TP_LEVELS_TOTAL = 3;
const double PARTIAL_TP_LEVEL_1_R = 1.0;
const double PARTIAL_TP_LEVEL_2_R = 2.0;
const double PARTIAL_TP_LEVEL_3_R = 3.0;
const double PARTIAL_TP_VOLUME_1 = 0.33;
const double PARTIAL_TP_VOLUME_2 = 0.33;
const double PARTIAL_TP_VOLUME_3 = 0.34;

bool PartialTPEnabled()
{
  return (Partial_TP_Mode == PARTIAL_TP_R_MULTIPLES);
}

double PartialTPLevelR(const int level_index)
{
  if(level_index == 0)
    return PARTIAL_TP_LEVEL_1_R;
  if(level_index == 1)
    return PARTIAL_TP_LEVEL_2_R;
  return PARTIAL_TP_LEVEL_3_R;
}

double PartialTPVolumeFraction(const int level_index)
{
  if(level_index == 0)
    return PARTIAL_TP_VOLUME_1;
  if(level_index == 1)
    return PARTIAL_TP_VOLUME_2;
  return PARTIAL_TP_VOLUME_3;
}

bool PartialTPLevelConfirmed(const SignalParams &signal_params,
                             const int level_index)
{
  if(level_index == 0)
    return signal_params.partial_tp1_confirmed;
  if(level_index == 1)
    return signal_params.partial_tp2_confirmed;
  return signal_params.partial_tp3_confirmed;
}

void MarkPartialTPLevelConfirmed(SignalParams &signal_params,
                                 const int level_index,
                                 const double closed_volume,
                                 const double close_price)
{
  datetime close_time = TimeCurrent();
  if(level_index == 0)
  {
    signal_params.partial_tp1_confirmed = true;
    signal_params.partial_tp1_closed_volume += closed_volume;
    signal_params.partial_tp1_close_price = close_price;
    signal_params.partial_tp1_close_time = close_time;
    return;
  }
  if(level_index == 1)
  {
    signal_params.partial_tp2_confirmed = true;
    signal_params.partial_tp2_closed_volume += closed_volume;
    signal_params.partial_tp2_close_price = close_price;
    signal_params.partial_tp2_close_time = close_time;
    return;
  }

  signal_params.partial_tp3_confirmed = true;
  signal_params.partial_tp3_closed_volume += closed_volume;
  signal_params.partial_tp3_close_price = close_price;
  signal_params.partial_tp3_close_time = close_time;
}

int ResolveFoundationLevelPositionStart()
{
  if(FOUNDATION_LEVEL_POSITION_START < 0)
    return 0;
  return FOUNDATION_LEVEL_POSITION_START;
}

double ResolveFoundationLevelExponentialMultiplier()
{
  if(FOUNDATION_LEVEL_EXPONENTIAL_MULTIPLIER <= 0.0)
    return 1.0;
  return FOUNDATION_LEVEL_EXPONENTIAL_MULTIPLIER;
}

int ResolveFoundationLevelStopLimit()
{
  if(FOUNDATION_LEVEL_STOP_LIMIT < 0)
    return 0;
  return FOUNDATION_LEVEL_STOP_LIMIT;
}

double ExecutionResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double ExecutionResolveDirectionMultiplier(const SignalTypes direction)
{
  if(direction == BULLISH)
    return 1.0;
  if(direction == BEARISH)
    return -1.0;
  return 0.0;
}

int ResolveStructureRangeStepDirection(const SignalTypes signal_type,
                                  const bool current_is_bottom)
{
  if(signal_type == BULLISH)
    return current_is_bottom ? 1 : -1;
  if(signal_type == BEARISH)
    return current_is_bottom ? -1 : 1;
  return 1;
}

double ExecutionCurrentPriceForDirection(const SignalTypes direction,
                                    const bool use_entry_side)
{
  if(direction == BULLISH)
    return use_entry_side ? g_ask : g_bid;
  return use_entry_side ? g_bid : g_ask;
}

void ExecutionAppendReason(string &target,
                      const string token)
{
  if(token == "")
    return;
  if(target == "")
  {
    target = token;
    return;
  }
  target = target + ";" + token;
}

int ExecutionDisplayLegNumber(const int level_index)
{
  if(level_index < 0)
    return 1;

  return level_index + 1;
}

bool IsLimitTriggerReached(const SignalTypes direction,
                           const double entry_side_price,
                           const double trigger_price)
{
  if(trigger_price <= 0.0)
    return false;

  if(direction == BULLISH)
    return (entry_side_price <= trigger_price);
  if(direction == BEARISH)
    return (entry_side_price >= trigger_price);
  return false;
}

bool IsLimitTriggerOppositeSide(const SignalTypes direction,
                                const double entry_side_price,
                                const double trigger_price)
{
  if(trigger_price <= 0.0)
    return false;

  if(direction == BULLISH)
    return (entry_side_price > trigger_price);
  if(direction == BEARISH)
    return (entry_side_price < trigger_price);
  return false;
}

bool UsesNonBreakoutLimitEdgeActivation(const SignalParams &signal_params,
                                        const ExecutionLegState &leg_state)
{
  if(!signal_params.entry_is_limit)
    return false;

  if(leg_state.level_index != 0)
    return false;

  if(SignalUsesBreakoutLimitAnchoring(signal_params))
    return false;

  return true;
}

bool ShouldArmNonBreakoutLimitActivation(const SignalParams &signal_params,
                                         const ExecutionLegState &leg_state,
                                         const double entry_side_price)
{
  if(!UsesNonBreakoutLimitEdgeActivation(signal_params, leg_state))
    return true;

  return IsLimitTriggerOppositeSide(signal_params.signal_type,
                                    entry_side_price,
                                    leg_state.entry_reference_price);
}

string ExecutionComposeLegComment(const SignalParams &signal_params,
                               const ExecutionLegState &leg_state)
{
  string direction_label = (signal_params.signal_type == BULLISH) ? "B" : "S";
  long entry_token = (long)signal_params.entry_time;
  if(entry_token < 0)
    entry_token = 0;
  entry_token = entry_token % 1000000;
  string engine_token = signal_params.engine_label;
  if(engine_token == "")
    engine_token = ExtremumEngineLabel(signal_params.engine_id);
  if(engine_token == "")
    engine_token = "ENGINE";
  int display_level = ExecutionDisplayLegNumber(leg_state.level_index);
  return StringFormat("EX_%s_%s_%d_L%d",
                      engine_token,
                      direction_label,
                      (int)entry_token,
                      display_level);
}

ulong ResolveExecutionMagicNumberForSignal(const SignalParams &signal_params)
{
  // One stable namespace owns all broker positions for this symbol.
  return g_execution_magic;
}

int CountPositionOpeningExecutionLegs(const SignalParams &signal_params)
{
  int total_levels = ArraySize(signal_params.execution_legs);
  int count = 0;
  for(int idx = 0; idx < total_levels; idx++)
  {
    if(signal_params.execution_legs[idx].opens_position)
      count++;
  }
  return count;
}

bool NextExecutionLegOpensPosition(const SignalParams &signal_params)
{
  int next_index = ArraySize(signal_params.execution_legs);
  return (next_index >= ResolveFoundationLevelPositionStart());
}

void ResetExecutionLegStateForWaiting(ExecutionLegState &state,
                                   const ExecutionLegState &template_state)
{
  int level_index = state.level_index;
  state = template_state;
  state.level_index        = level_index;
  state.status             = EXECUTION_LEG_WAITING;
  state.entry_price        = 0.0;
  state.take_profit_price  = 0.0;
  state.next_level_price   = template_state.next_level_price;
	  state.last_action_time   = 0;
	  state.position_ticket    = 0;
	  state.closed_position_ticket = 0;
	  state.position_comment   = "";
	  state.broker_close_confirmed = false;
	  state.close_source       = "";
	  state.closed_volume      = 0.0;
	  state.realized_profit    = 0.0;
	  state.close_price        = 0.0;
	  state.close_time         = 0;
	}

double ExecutionPointsBetween(const SignalTypes direction,
                         const double reference_price,
                         const double candidate_price,
                         const double point_size)
{
  if(point_size <= 0.0)
    return 0.0;

  if(direction == BULLISH)
    return (reference_price - candidate_price) / point_size;
  return (candidate_price - reference_price) / point_size;
}

double ExecutionAbsolutePriceDistancePoints(const double reference_price,
                                       const double candidate_price)
{
  double point_size = ExecutionResolvePointSize();
  if(point_size <= 0.0)
    return 0.0;

  return MathAbs(reference_price - candidate_price) / point_size;
}

double ExecutionResolveMinimumLegDistancePoints()
{
  double minimum_points = EnforceBrokerDistance(g_symbol_constraints, 1.0);
  if(minimum_points <= 0.0)
    minimum_points = 1.0;
  return minimum_points;
}

bool ExecutionHasMeaningfulPriceGap(const double reference_price,
                               const double candidate_price,
                               const double minimum_distance_points = 0.0)
{
  if(reference_price <= 0.0 || candidate_price <= 0.0)
    return false;

  double required_points = minimum_distance_points;
  if(required_points <= 0.0)
    required_points = ExecutionResolveMinimumLegDistancePoints();

  double actual_points = ExecutionAbsolutePriceDistancePoints(reference_price,
                                                         candidate_price);
  return (actual_points + 1.0e-9 >= required_points);
}

double ExecutionResolveLegReferencePrice(const SignalParams &signal_params,
                                      const ExecutionLegState &leg_state)
{
  double reference_price = leg_state.entry_reference_price;
  if(reference_price <= 0.0)
    reference_price = signal_params.entry_price;
  if(reference_price <= 0.0)
    reference_price = signal_params.execution_entry_reference_price;
  return reference_price;
}

bool ShouldActivateBreakoutLimitEntry(const SignalTypes direction,
                                      const double entry_side_price,
                                      const double trigger_price)
{
  if(trigger_price <= 0.0)
    return false;

  if(direction == BULLISH)
    return (entry_side_price >= trigger_price);
  if(direction == BEARISH)
    return (entry_side_price <= trigger_price);
  return false;
}

bool ShouldBlockNextLevelByStopLimit(const int level_stop_limit,
                                     const int active_level_index)
{
  if(level_stop_limit <= 0)
    return false;
  if(active_level_index < 0)
    return false;

  int reached_level = ExecutionDisplayLegNumber(active_level_index);
  return (reached_level >= level_stop_limit);
}

double GetExecutionStopReferencePrice(SignalTypes direction, SignalParams &signal_params, ExecutionLegState &execution_leg_state)
{
  if(execution_leg_state.level_index == 0 &&
     (signal_params.entry_is_limit || signal_params.entry_trigger_mode == LEVEL_AS_ZONE))
  {
    if(signal_params.entry_price > 0.0)
      return signal_params.entry_price;
    if(signal_params.execution_entry_reference_price > 0.0)
      return signal_params.execution_entry_reference_price;
  }

  double base_entry_price = ExecutionCurrentPriceForDirection(direction, true);
  double stop_entry_price = execution_leg_state.entry_reference_price;

  if(direction == BULLISH)
  {
    base_entry_price = base_entry_price + (signal_params.execution_entry_offset_points / g_decimal_digits);

    if(base_entry_price < stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE FALLS

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }
  if(direction == BEARISH)
  {
    base_entry_price = base_entry_price - (signal_params.execution_entry_offset_points / g_decimal_digits);

    if(base_entry_price > stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE ROCKET

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }

  return base_entry_price;
}

double GetExecutionNextLevelPrice(SignalTypes direction, SignalParams &signal_params, ExecutionLegState &execution_leg_state)
{
  double execution_pending_price  = 0;
  double execution_base_entry_price   = ExecutionResolveLegReferencePrice(signal_params,
                                                                  execution_leg_state);
  double execution_next_level_price   = execution_leg_state.next_level_price;

  if(StrategyRangeUsesStructure())
  {
    double structure_level_price = 0.0;
    if(ResolveStructureExecutionLevelPrice(signal_params, execution_leg_state.level_index, structure_level_price))
    {
      double minimum_distance_points = ResolveExecutionLegDistancePoints(signal_params,
                                                                      execution_leg_state);
      if(minimum_distance_points <= 0.0)
        minimum_distance_points = ExecutionResolveMinimumLegDistancePoints();

      if(execution_base_entry_price > 0.0 &&
         !ExecutionHasMeaningfulPriceGap(execution_base_entry_price,
                                    structure_level_price,
                                    minimum_distance_points))
      {
        double fallback_price = ComputeNextLevelPrice(signal_params,
                                                      execution_base_entry_price,
                                                      minimum_distance_points);
        if(fallback_price > 0.0)
          return fallback_price;
      }
      return structure_level_price;
    }
    return execution_next_level_price;
  }

  // Recompute from entry_reference_price each tick using per-level distance
  double level_distance_pts      = ComputeLevelDistancePoints(signal_params, execution_leg_state.level_index);

  if(direction == BULLISH)
  {
    execution_pending_price = execution_base_entry_price - (level_distance_pts / g_decimal_digits);

    if(execution_pending_price < execution_next_level_price) return execution_pending_price; // FOLLOWS THE PRICE FALLS

    return execution_next_level_price == 0 ? execution_pending_price : execution_next_level_price;
  }
  if(direction == BEARISH)
  {
    execution_pending_price = execution_base_entry_price + (level_distance_pts / g_decimal_digits);

    if(execution_pending_price > execution_next_level_price) return execution_pending_price; // FOLLOWS THE PRICE ROCKET

    return execution_next_level_price == 0 ? execution_pending_price : execution_next_level_price;
  }

  return execution_pending_price;
}

double GetExecutionTakeProfitPrice(SignalTypes direction, SignalParams &signal_params, ExecutionLegState &execution_leg_state)
{
  double execution_tp_price            = 0;
  double execution_base_entry_price        = execution_leg_state.entry_reference_price;
  double execution_take_profit_price       = execution_leg_state.take_profit_price;
  // Per-level TP span based on exponential distance
  double level_distance_pts           = ResolveExecutionLegDistancePoints(signal_params, execution_leg_state);
  double tp_factor = (TP_Percent > 0.0) ? (TP_Percent / 100.0) : 1.0;
  double tp_span_pts = level_distance_pts * tp_factor;
  tp_span_pts = EnforceBrokerDistance(g_symbol_constraints, tp_span_pts);

  if(direction == BULLISH)
  {
    execution_tp_price = execution_base_entry_price + (tp_span_pts / g_decimal_digits);

    if(execution_tp_price > execution_take_profit_price)
    {
      execution_tp_price = execution_tp_price; // FOLLOWS THE PRICE ROCKET
    } else {
      execution_tp_price = execution_take_profit_price == 0 ? execution_tp_price : execution_take_profit_price;
    }
  }
  if(direction == BEARISH)
  {
    execution_tp_price = execution_base_entry_price - (tp_span_pts / g_decimal_digits);

    if(execution_tp_price < execution_take_profit_price)
    {
      execution_tp_price = execution_tp_price; // FOLLOWS THE PRICE FALLS
    } else {
      execution_tp_price = execution_take_profit_price == 0 ? execution_tp_price : execution_take_profit_price;
    }
  }

  return execution_tp_price;
}

void ResetExecutionLegPricesByDirection(SignalParams &signal_params, int execution_leg_index)
{
  if(signal_params.signal_type == BULLISH)
  {
    signal_params.execution_legs[execution_leg_index].entry_reference_price   = DBL_MAX;
    signal_params.execution_legs[execution_leg_index].next_level_price        = DBL_MAX;
    signal_params.execution_legs[execution_leg_index].take_profit_price       = -DBL_MAX;
  }
  if(signal_params.signal_type == BEARISH)
  {
    signal_params.execution_legs[execution_leg_index].entry_reference_price   = -DBL_MAX;
    signal_params.execution_legs[execution_leg_index].next_level_price        = -DBL_MAX;
    signal_params.execution_legs[execution_leg_index].take_profit_price       = DBL_MAX;
  }
}

// --- New pricing helpers (points-based, broker-safe) ---

double ComputeLevelDistancePoints(const SignalParams &signal_params,
                                  const int level_index)
{
  double base_pts = signal_params.execution_base_distance_points;
  if(base_pts <= 0.0)
    return 0.0;
  double mult = ResolveFoundationLevelExponentialMultiplier();
  double distance_pts = base_pts * MathPow(mult, (double)level_index);
  distance_pts = EnforceBrokerDistance(g_symbol_constraints, distance_pts);
  return distance_pts;
}

double ResolveExecutionLegDistancePoints(const SignalParams &signal_params,
                                      const ExecutionLegState &state)
{
  if(StrategyRangeUsesStructure())
  {
    double structure_level_price = 0.0;
    if(!ResolveStructureExecutionLevelPrice(signal_params, state.level_index, structure_level_price))
      return signal_params.execution_base_distance_points;

    double entry_price = state.entry_reference_price;
    if(entry_price <= 0.0)
      entry_price = signal_params.execution_entry_reference_price;
    if(entry_price <= 0.0)
      entry_price = signal_params.entry_price;

    double point_size = ExecutionResolvePointSize();
    if(point_size <= 0.0 || entry_price <= 0.0)
      return 0.0;

    double distance_pts = MathAbs(entry_price - structure_level_price) / point_size;
    distance_pts = EnforceBrokerDistance(g_symbol_constraints, distance_pts);
    return distance_pts;
  }

  return ComputeLevelDistancePoints(signal_params, state.level_index);
}

double ComputeEntryReferencePrice(const SignalParams &signal_params,
                                  const ExecutionLegState &state)
{
  double point_size = ExecutionResolvePointSize();
  double entry_side = ExecutionCurrentPriceForDirection(signal_params.signal_type, true);
  double offset_pts = signal_params.execution_entry_offset_points;
  if(offset_pts < 0.0)
    offset_pts = 0.0;

  double candidate = entry_side;
  if(signal_params.signal_type == BULLISH)
    candidate = entry_side + offset_pts * point_size;
  else if(signal_params.signal_type == BEARISH)
    candidate = entry_side - offset_pts * point_size;

  // Trail adverse only
  double prev = state.entry_reference_price;
  if(prev > 0.0)
  {
    if(signal_params.signal_type == BULLISH && candidate < prev)
      return candidate;
    if(signal_params.signal_type == BEARISH && candidate > prev)
      return candidate;
    return prev;
  }
  return candidate;
}

double ComputeNextLevelPrice(const SignalParams &signal_params,
                             const double entry_reference_price,
                             const double level_distance_points)
{
  double point_size = ExecutionResolvePointSize();
  if(level_distance_points <= 0.0 || point_size <= 0.0 || entry_reference_price <= 0.0)
    return 0.0;
  if(signal_params.signal_type == BULLISH)
    return entry_reference_price - level_distance_points * point_size;
  if(signal_params.signal_type == BEARISH)
    return entry_reference_price + level_distance_points * point_size;
  return 0.0;
}

double ClampPointsToBroker(const double points_value)
{
  return EnforceBrokerDistance(g_symbol_constraints, points_value);
}

bool FindLatestFilledExecutionLeg(const SignalParams &signal_params,
                               ExecutionLegState &state_out)
{
  int total_levels = ArraySize(signal_params.execution_legs);
  if(total_levels <= 0)
    return false;

  for(int idx = total_levels - 1; idx >= 0; idx--)
  {
    ExecutionLegState state = signal_params.execution_legs[idx];
    if(state.level_index < 0)
      continue;
    if(state.entry_price <= 0.0)
      continue;
    if(state.status == EXECUTION_LEG_INACTIVE ||
       state.status == EXECUTION_LEG_WAITING ||
       state.status == EXECUTION_LEG_PENDING)
      continue;
    state_out = state;
    return true;
  }

  return false;
}

bool ExecutionSignalHasExecutedLeg(const SignalParams &signal_params)
{
  int total_levels = ArraySize(signal_params.execution_legs);
  for(int idx = 0; idx < total_levels; idx++)
  {
    ExecutionLegState state = signal_params.execution_legs[idx];
    if(state.entry_price <= 0.0)
      continue;
    if(state.status == EXECUTION_LEG_ACTIVE ||
       state.status == EXECUTION_LEG_COMPLETED)
      return true;
  }
  return false;
}

bool ResolveSignalStructureSnapshot(const SignalParams &signal_params,
                                    StochasticMarketStructure &structure)
{
  bool valid = false;
  switch(signal_params.strategy_context)
  {
    case CONTEXT_SLOT_TREND:
      valid = signal_params.trend_structure_valid;
      structure = signal_params.trend_structure_data;
      break;
    case CONTEXT_SLOT_MACRO:
      valid = signal_params.macro_structure_valid;
      structure = signal_params.macro_structure_data;
      break;
    case CONTEXT_SLOT_SESSION:
      valid = signal_params.session_structure_valid;
      structure = signal_params.session_structure_data;
      break;
    case CONTEXT_SLOT_BASE:
    default:
      valid = signal_params.base_structure_valid;
      structure = signal_params.base_structure_data;
      break;
  }
  return valid;
}

bool ResolveSignalStructureRange(const SignalParams &signal_params,
                                 double &peak_price,
                                 double &bottom_price,
                                 bool &current_is_bottom)
{
  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;

  StochasticMarketStructure structure;
  if(!ResolveSignalStructureSnapshot(signal_params, structure))
    return false;

  return ResolveStructureReferenceRange(structure,
                                        peak_price,
                                        bottom_price,
                                        current_is_bottom);
}

bool ResolveStructureSnapshotTimeForContext(const StrategyContextTypes context,
                                            const StochasticMarketStructure &structure,
                                            datetime &time_out)
{
  time_out = 0;

  StrategyStructureLayerContext ctx = BuildStructureLayerForContext(context);
  datetime resolved = ResolveStructureSnapshotTimestamp(structure, ctx);
  if(resolved <= 0)
    return false;

  time_out = resolved;
  return true;
}

bool ResolveStructureRangeEntryPercent(const SignalParams &signal_params,
                                  const double entry_price,
                                  double &entry_percent,
                                  double &peak_price,
                                  double &bottom_price,
                                  bool &current_is_bottom)
{
  entry_percent = 0.0;
  peak_price = 0.0;
  bottom_price = 0.0;
  current_is_bottom = false;

  if(entry_price <= 0.0)
    return false;

  if(!ResolveSignalStructureRange(signal_params,
                                  peak_price,
                                  bottom_price,
                                  current_is_bottom))
    return false;

  return ResolveStructurePercentForPrice(peak_price,
                                         bottom_price,
                                         current_is_bottom,
                                         entry_price,
                                         entry_percent);
}

bool SignalHasResolvedStructureEntryAnchor(const SignalParams &signal_params)
{
  if(!signal_params.resolved_structure_entry.valid)
    return false;

  if(!MathIsValidNumber(signal_params.resolved_structure_entry.percent))
    return false;

  if(!MathIsValidNumber(signal_params.resolved_structure_entry.price))
    return false;

  return (signal_params.resolved_structure_entry.price > 0.0);
}

bool ResolveStructureRangeCanonicalEntryContext(const SignalParams &signal_params,
                                           const double entry_price,
                                           double &entry_percent_out,
                                           double &band_lower_out,
                                           double &band_upper_out,
                                           double &canonical_percent_out,
                                           double &canonical_price_out,
                                           double &peak_price_out,
                                           double &bottom_price_out,
                                           bool &current_is_bottom_out,
                                           bool &band_target_used_out)
{
  entry_percent_out = 0.0;
  band_lower_out = 0.0;
  band_upper_out = 0.0;
  canonical_percent_out = 0.0;
  canonical_price_out = 0.0;
  peak_price_out = 0.0;
  bottom_price_out = 0.0;
  current_is_bottom_out = false;
  band_target_used_out = false;

  if(entry_price <= 0.0)
    return false;

  if(!ResolveStructureRangeEntryPercent(signal_params,
                                   entry_price,
                                   entry_percent_out,
                                   peak_price_out,
                                   bottom_price_out,
                                   current_is_bottom_out))
    return false;

  canonical_percent_out = entry_percent_out;
  canonical_price_out = entry_price;

  if(SignalHasResolvedStructureEntryAnchor(signal_params))
  {
    canonical_percent_out = signal_params.resolved_structure_entry.percent;
    canonical_price_out   = signal_params.resolved_structure_entry.price;
    band_target_used_out  = true;
    return true;
  }

  if(!signal_params.entry_is_limit || SignalUsesBreakoutLimitAnchoring(signal_params))
    return true;

  bool band_ok = ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
                                                       ArraySize(g_structure_fibo_config.levels),
                                                       entry_percent_out,
                                                       band_lower_out,
                                                       band_upper_out);
  if(!band_ok)
  {
    band_ok = ResolveFibonacciRangeForPercent(g_structure_fibo_config.levels,
                                              ArraySize(g_structure_fibo_config.levels),
                                              entry_percent_out,
                                              band_lower_out,
                                              band_upper_out);
  }
  if(!band_ok)
    return true;

  double lower_price = 0.0;
  double upper_price = 0.0;
  if(!ResolveStructurePriceForPercent(peak_price_out,
                                      bottom_price_out,
                                      current_is_bottom_out,
                                      band_lower_out,
                                      lower_price) ||
     !ResolveStructurePriceForPercent(peak_price_out,
                                      bottom_price_out,
                                      current_is_bottom_out,
                                      band_upper_out,
                                      upper_price))
    return true;

  double target_percent = 0.0;
  double target_price = 0.0;
  if(!ResolveDirectionalLimitBandTarget(signal_params.signal_type,
                                        current_is_bottom_out,
                                        band_lower_out,
                                        band_upper_out,
                                        lower_price,
                                        upper_price,
                                        target_percent,
                                        target_price))
    return true;

  canonical_percent_out = target_percent;
  canonical_price_out = target_price;
  band_target_used_out = true;
  return true;
}

bool ResolveStructureEntryRange(const SignalParams &signal_params,
                                const double entry_price,
                                double &entry_percent_out,
                                double &range_lower_out,
                                double &range_upper_out)
{
  entry_percent_out = 0.0;
  range_lower_out = 0.0;
  range_upper_out = 0.0;

  if(!g_structure_fibo_config.valid)
    return false;

  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveStructureRangeEntryPercent(signal_params,
                                   entry_price,
                                   entry_percent,
                                   peak_price,
                                   bottom_price,
                                   current_is_bottom))
    return false;

  double lower = 0.0;
  double upper = 0.0;
  if(!ResolveFibonacciRangeForPercent(g_structure_fibo_config.levels,
                                      ArraySize(g_structure_fibo_config.levels),
                                      entry_percent,
                                      lower,
                                      upper))
    return false;

  entry_percent_out = entry_percent;
  range_lower_out = lower;
  range_upper_out = upper;
  return true;
}

bool SignalUsesBreakoutLimitAnchoring(const SignalParams &signal_params)
{
  if(signal_params.entry_trigger_mode != LEVELS_AS_LIMITS)
    return false;

  if(!signal_params.entry_is_limit)
    return false;

  if(signal_params.strategy_context != CONTEXT_SLOT_BASE)
    return false;

  return false;
}

bool ResolveBreakoutLimitOppositeEndpointPercent(const double entry_percent,
                                                 double &opposite_percent_out)
{
  opposite_percent_out = 0.0;

  if(!g_structure_fibo_config.valid)
    return false;

  int total_levels = ArraySize(g_structure_fibo_config.levels);
  if(total_levels < 2)
    return false;

  double lower = 0.0;
  double upper = 0.0;
  if(!ResolveFibonacciRangeForPercentStrict(g_structure_fibo_config.levels,
                                            total_levels,
                                            entry_percent,
                                            lower,
                                            upper))
  {
    if(!ResolveFibonacciRangeForPercent(g_structure_fibo_config.levels,
                                        total_levels,
                                        entry_percent,
                                        lower,
                                        upper))
      return false;
  }

  if(MathAbs(entry_percent - lower) <= MathAbs(entry_percent - upper))
  {
    opposite_percent_out = upper;
    return true;
  }

  opposite_percent_out = lower;
  return true;
}

bool ResolveExecutionTraversalForLeg(const SignalParams &signal_params,
                                  const double entry_percent,
                                  const int level_index,
                                  double &start_percent_out,
                                  int &steps_out,
                                  bool &return_anchor_only_out,
                                  double &anchor_percent_out)
{
  steps_out = signal_params.structure_range_step_offset + level_index;
  if(steps_out <= 0)
    steps_out = 1;
  return_anchor_only_out = false;
  anchor_percent_out = 0.0;

  if(!SignalUsesBreakoutLimitAnchoring(signal_params))
    return true;

  if(!ResolveBreakoutLimitOppositeEndpointPercent(entry_percent, anchor_percent_out))
    return false;

  // Breakout level0 is the anchored opposite endpoint; deeper levels continue
  // stepping from that anchored endpoint.
  if(level_index <= 0)
  {
    return_anchor_only_out = true;
    return true;
  }

  start_percent_out = anchor_percent_out;
  steps_out = signal_params.structure_range_step_offset + (level_index - 1);
  if(steps_out <= 0)
    steps_out = 1;

  return true;
}

bool ResolveStructureExecutionLevelPercent(const SignalParams &signal_params,
                                      const int level_index,
                                      double &level_percent_out)
{
  level_percent_out = 0.0;

  if(!g_structure_fibo_config.valid || !g_structure_fibo_config.cycle_valid)
    return false;

  double entry_price = signal_params.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.execution_entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double band_lower = 0.0;
  double band_upper = 0.0;
  double canonical_entry_percent = 0.0;
  double canonical_entry_price = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  bool band_target_used = false;
  if(!ResolveStructureRangeCanonicalEntryContext(signal_params,
                                            entry_price,
                                            entry_percent,
                                            band_lower,
                                            band_upper,
                                            canonical_entry_percent,
                                            canonical_entry_price,
                                            peak_price,
                                            bottom_price,
                                            current_is_bottom,
                                            band_target_used))
    return false;

  double start_percent = canonical_entry_percent;
  int steps = signal_params.structure_range_step_offset + level_index;
  bool return_anchor_only = false;
  double anchor_percent = 0.0;
  if(!ResolveExecutionTraversalForLeg(signal_params,
                                   canonical_entry_percent,
                                   level_index,
                                   start_percent,
                                   steps,
                                   return_anchor_only,
                                   anchor_percent))
    return false;
  if(return_anchor_only)
  {
    level_percent_out = anchor_percent;
    return true;
  }

  double level_percent = 0.0;
  int step_dir = ResolveStructureRangeStepDirection(signal_params.signal_type, current_is_bottom);
  if(!ResolveFibonacciNextPercentCycledWithCycle(g_structure_fibo_config.cycle_levels,
                                                 ArraySize(g_structure_fibo_config.cycle_levels),
                                                 g_structure_fibo_config.cycle_allow_zero,
                                                 start_percent,
                                                 steps,
                                                 step_dir,
                                                 level_percent))
    return false;

  level_percent_out = level_percent;
  return true;
}

bool ResolveStructureExecutionLevelPrice(const SignalParams &signal_params,
                                    const int level_index,
                                    double &price_out)
{
  price_out = 0.0;
  if(!g_structure_fibo_config.valid || !g_structure_fibo_config.cycle_valid)
    return false;

  double entry_price = signal_params.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.execution_entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double canonical_entry_percent = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  double band_lower = 0.0;
  double band_upper = 0.0;
  double canonical_entry_price = 0.0;
  bool band_target_used = false;
  if(!ResolveStructureRangeCanonicalEntryContext(signal_params,
                                            entry_price,
                                            entry_percent,
                                            band_lower,
                                            band_upper,
                                            canonical_entry_percent,
                                            canonical_entry_price,
                                            peak_price,
                                            bottom_price,
                                            current_is_bottom,
                                            band_target_used))
    return false;

  double start_percent = canonical_entry_percent;
  int steps = signal_params.structure_range_step_offset + level_index;
  bool return_anchor_only = false;
  double anchor_percent = 0.0;
  if(!ResolveExecutionTraversalForLeg(signal_params,
                                   canonical_entry_percent,
                                   level_index,
                                   start_percent,
                                   steps,
                                   return_anchor_only,
                                   anchor_percent))
    return false;
  if(return_anchor_only)
  {
    return ResolveStructurePriceForPercent(peak_price,
                                           bottom_price,
                                           current_is_bottom,
                                           anchor_percent,
                                           price_out);
  }

  double level_percent = 0.0;
  int step_dir = ResolveStructureRangeStepDirection(signal_params.signal_type, current_is_bottom);
  if(!ResolveFibonacciNextPercentCycledWithCycle(g_structure_fibo_config.cycle_levels,
                                                 ArraySize(g_structure_fibo_config.cycle_levels),
                                                 g_structure_fibo_config.cycle_allow_zero,
                                                 start_percent,
                                                 steps,
                                                 step_dir,
                                                 level_percent))
    return false;

  return ResolveStructurePriceForPercent(peak_price,
                                         bottom_price,
                                         current_is_bottom,
                                         level_percent,
                                         price_out);
}

bool ResolveStructureExecutionBaseDistance(const SignalParams &signal_params,
                                      const double entry_reference_price,
                                      int &steps_out,
                                      double &distance_points_out)
{
  steps_out = 1;
  distance_points_out = 0.0;

  if(!g_structure_fibo_config.valid || !g_structure_fibo_config.cycle_valid)
    return false;

  double entry_price = entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double canonical_entry_percent = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  double band_lower = 0.0;
  double band_upper = 0.0;
  double canonical_entry_price = 0.0;
  bool band_target_used = false;
  if(!ResolveStructureRangeCanonicalEntryContext(signal_params,
                                            entry_price,
                                            entry_percent,
                                            band_lower,
                                            band_upper,
                                            canonical_entry_percent,
                                            canonical_entry_price,
                                            peak_price,
                                            bottom_price,
                                            current_is_bottom,
                                            band_target_used))
    return false;

  int step_dir = ResolveStructureRangeStepDirection(signal_params.signal_type, current_is_bottom);

  double point_size = ExecutionResolvePointSize();
  if(point_size <= 0.0)
    return false;

  int total_levels = ArraySize(g_structure_fibo_config.levels);
  if(total_levels < 2)
    return false;

  double required_points = EnforceBrokerDistance(g_symbol_constraints, Strategy_Range_Points);
  int max_steps = total_levels + 10;

  if(SignalUsesBreakoutLimitAnchoring(signal_params))
  {
    double anchored_percent = 0.0;
    if(!ResolveBreakoutLimitOppositeEndpointPercent(canonical_entry_percent, anchored_percent))
      return false;

    double anchored_price = 0.0;
    if(!ResolveStructurePriceForPercent(peak_price,
                                        bottom_price,
                                        current_is_bottom,
                                        anchored_percent,
                                        anchored_price))
      return false;

    steps_out = 1;
    distance_points_out = MathAbs(entry_price - anchored_price) / point_size;
    distance_points_out = EnforceBrokerDistance(g_symbol_constraints, distance_points_out);
    if(required_points > 0.0 && distance_points_out < required_points)
      return false;
    return (distance_points_out > 0.0);
  }

  if(signal_params.entry_trigger_mode == LEVEL_AS_ZONE && required_points > 0.0)
  {
    for(int step = 1; step <= max_steps; step++)
    {
      double next_percent = 0.0;
      if(!ResolveFibonacciNextPercentCycledWithCycle(g_structure_fibo_config.cycle_levels,
                                                     ArraySize(g_structure_fibo_config.cycle_levels),
                                                     g_structure_fibo_config.cycle_allow_zero,
                                                     canonical_entry_percent,
                                                     step,
                                                     step_dir,
                                                     next_percent))
        return false;

      double next_price = 0.0;
      if(!ResolveStructurePriceForPercent(peak_price,
                                          bottom_price,
                                          current_is_bottom,
                                          next_percent,
                                          next_price))
        continue;

      double distance_points = MathAbs(entry_price - next_price) / point_size;
      if(distance_points >= required_points)
      {
        steps_out = step;
        distance_points_out = EnforceBrokerDistance(g_symbol_constraints, distance_points);
        return (distance_points_out > 0.0);
      }
    }

    return false;
  }

  double next_percent = 0.0;
  if(!ResolveFibonacciNextPercentCycledWithCycle(g_structure_fibo_config.cycle_levels,
                                                 ArraySize(g_structure_fibo_config.cycle_levels),
                                                 g_structure_fibo_config.cycle_allow_zero,
                                                 canonical_entry_percent,
                                                 1,
                                                 step_dir,
                                                 next_percent))
    return false;

  double next_price = 0.0;
  if(!ResolveStructurePriceForPercent(peak_price,
                                      bottom_price,
                                      current_is_bottom,
                                      next_percent,
                                      next_price))
    return false;

  steps_out = 1;
  distance_points_out = MathAbs(entry_price - next_price) / point_size;
  distance_points_out = EnforceBrokerDistance(g_symbol_constraints, distance_points_out);
  return (distance_points_out > 0.0);
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LEG_HELPERS_MQH_
