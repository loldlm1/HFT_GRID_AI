//+------------------------------------------------------------------+
//|                               microservices/trading_signals/... |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_

double GridResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;
  return point_size;
}

double GridResolveDirectionMultiplier(const SignalTypes direction)
{
  if(direction == BULLISH)
    return 1.0;
  if(direction == BEARISH)
    return -1.0;
  return 0.0;
}

int ResolveFibonacciStepDirection(const SignalTypes signal_type,
                                  const bool current_is_bottom)
{
  if(signal_type == BULLISH)
    return current_is_bottom ? 1 : -1;
  if(signal_type == BEARISH)
    return current_is_bottom ? -1 : 1;
  return 1;
}

double GridCurrentPriceForDirection(const SignalTypes direction,
                                    const bool use_entry_side)
{
  if(direction == BULLISH)
    return use_entry_side ? g_ask : g_bid;
  return use_entry_side ? g_bid : g_ask;
}

bool GridGuardrailsAllowOrder(const double normalized_volume,
                              string &reason)
{
  reason = "";
  if(g_points_spread > Max_Spread)
  {
    reason = StringFormat("spread=%.1f>%.1f",
                          g_points_spread,
                          Max_Spread);
    return false;
  }

  double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  if(free_margin <= 0.0)
    return true;

  double margin_per_lot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
  if(margin_per_lot <= 0.0)
  {
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double price         = GridCurrentPriceForDirection(BULLISH, true);
    double leverage      = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
    if(contract_size > 0.0 && leverage > 0.0)
      margin_per_lot = (contract_size * price) / leverage;
  }

  if(margin_per_lot <= 0.0)
    return true;

  double required_margin = margin_per_lot * normalized_volume;
  if(required_margin <= 0.0)
    return true;

  if(free_margin < required_margin)
  {
    reason = StringFormat("margin=%.2f<%.2f",
                          free_margin,
                          required_margin);
    return false;
  }

  return true;
}

bool GridGuardrailsAllowOrder(const double normalized_volume)
{
  string reason = "";
  return GridGuardrailsAllowOrder(normalized_volume, reason);
}

void GridAppendReason(string &target,
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

string GridComposeLevelComment(const SignalParams &signal_params,
                               const GridOrderState &order_state)
{
  string direction_label = (signal_params.signal_type == BULLISH) ? "B" : "S";
  datetime entry_time    = signal_params.entry_time;
  string time_label      = TimeToString(entry_time, TIME_MINUTES);
  ENUM_TIMEFRAMES tf = signal_params.strategy_timeframe;
  if(tf == PERIOD_CURRENT)
    tf = Strategy_Timeframe;
  string tf_label = EnumToString(tf);
  return StringFormat("GRID_%s_%s_%s_L%d",
                      direction_label,
                      tf_label,
                      time_label,
                      order_state.level_index);
}

int GridCountPositionOpeningLevels(const SignalParams &signal_params)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  int count = 0;
  for(int idx = 0; idx < total_levels; idx++)
  {
    if(signal_params.grid_orders[idx].opens_position)
      count++;
  }
  return count;
}

bool GridNextLevelOpensPosition(const SignalParams &signal_params)
{
  int next_index = ArraySize(signal_params.grid_orders);
  int start_level = Grid_Level_Position_Start;
  if(start_level < 0)
    start_level = 0;
  return (next_index >= start_level);
}

void GridResetOrderStateForWaiting(GridOrderState &state,
                                   const GridOrderState &template_state)
{
  int level_index = state.level_index;
  state = template_state;
  state.level_index        = level_index;
  state.status             = GRID_ORDER_WAITING;
  state.entry_price        = 0.0;
  state.take_profit_price  = 0.0;
  state.next_level_price   = template_state.next_level_price;
  state.last_action_time   = 0;
  state.position_ticket    = 0;
  state.position_comment   = "";
}

double GridPointsBetween(const SignalTypes direction,
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
                                     const bool next_level_opens_position,
                                     const int position_levels)
{
  if(level_stop_limit <= 0)
    return false;
  if(!next_level_opens_position)
    return false;
  return (position_levels >= level_stop_limit);
}

double GetGridStopReferencePrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  if(grid_order_state.level_index == 0 &&
     (signal_params.entry_is_limit || signal_params.entry_trigger_mode == LEVEL_AS_ZONE))
  {
    if(signal_params.entry_price > 0.0)
      return signal_params.entry_price;
    if(signal_params.grid_entry_reference_price > 0.0)
      return signal_params.grid_entry_reference_price;
  }

  double base_entry_price = GridCurrentPriceForDirection(direction, true);
  double stop_entry_price = grid_order_state.entry_reference_price;

  if(direction == BULLISH)
  {
    base_entry_price = base_entry_price + (signal_params.grid_entry_offset_points / g_decimal_digits);

    if(base_entry_price < stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE FALLS

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }
  if(direction == BEARISH)
  {
    base_entry_price = base_entry_price - (signal_params.grid_entry_offset_points / g_decimal_digits);

    if(base_entry_price > stop_entry_price) return base_entry_price; // FOLLOWS THE PRICE ROCKET

    return stop_entry_price == 0 ? base_entry_price : stop_entry_price;
  }

  return base_entry_price;
}

double GetGridNextLevelPrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  double grid_raw_pending_price  = 0;
  double grid_base_entry_price   = grid_order_state.entry_reference_price;
  double grid_next_level_price   = grid_order_state.next_level_price;

  if(Grid_Base_Strategy_Type == FIB_LEVEL_RANGE)
  {
    double fib_level_price = 0.0;
    if(ResolveFibonacciGridLevelPrice(signal_params, grid_order_state.level_index, fib_level_price))
      return fib_level_price;
    return grid_next_level_price;
  }

  // Recompute from entry_reference_price each tick using per-level distance
  double level_distance_pts      = ComputeLevelDistancePoints(signal_params, grid_order_state.level_index);

  if(direction == BULLISH)
  {
    grid_raw_pending_price = grid_base_entry_price - (level_distance_pts / g_decimal_digits);

    if(grid_raw_pending_price < grid_next_level_price) return grid_raw_pending_price; // FOLLOWS THE PRICE FALLS

    return grid_next_level_price == 0 ? grid_raw_pending_price : grid_next_level_price;
  }
  if(direction == BEARISH)
  {
    grid_raw_pending_price = grid_base_entry_price + (level_distance_pts / g_decimal_digits);

    if(grid_raw_pending_price > grid_next_level_price) return grid_raw_pending_price; // FOLLOWS THE PRICE ROCKET

    return grid_next_level_price == 0 ? grid_raw_pending_price : grid_next_level_price;
  }

  return grid_raw_pending_price;
}

double GetGridTakeProfitPrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  double grid_raw_tp_price            = 0;
  double grid_base_entry_price        = grid_order_state.entry_reference_price;
  double grid_take_profit_price       = grid_order_state.take_profit_price;
  // Per-level TP span based on exponential distance
  double level_distance_pts           = ResolveGridLevelDistancePoints(signal_params, grid_order_state);
  double tp_span_pts;
  if(Grid_Points_TP > 0.0)
    tp_span_pts = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_TP);
  else
    tp_span_pts = level_distance_pts * (TP_Percent / 100.0);

  if(direction == BULLISH)
  {
    grid_raw_tp_price = grid_base_entry_price + (tp_span_pts / g_decimal_digits);

    if(grid_raw_tp_price > grid_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE ROCKET
    } else {
      grid_raw_tp_price = grid_take_profit_price == 0 ? grid_raw_tp_price : grid_take_profit_price;
    }
  }
  if(direction == BEARISH)
  {
    grid_raw_tp_price = grid_base_entry_price - (tp_span_pts / g_decimal_digits);

    if(grid_raw_tp_price < grid_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE FALLS
    } else {
      grid_raw_tp_price = grid_take_profit_price == 0 ? grid_raw_tp_price : grid_take_profit_price;
    }
  }

  return grid_raw_tp_price;
}

void ResetGridOrderPricesByDirection(SignalParams &signal_params, int grid_order_level)
{
  if(signal_params.signal_type == BULLISH)
  {
    signal_params.grid_orders[grid_order_level].entry_reference_price   = DBL_MAX;
    signal_params.grid_orders[grid_order_level].next_level_price        = DBL_MAX;
    signal_params.grid_orders[grid_order_level].take_profit_price       = -DBL_MAX;
  }
  if(signal_params.signal_type == BEARISH)
  {
    signal_params.grid_orders[grid_order_level].entry_reference_price   = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].next_level_price        = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].take_profit_price       = DBL_MAX;
  }
}

// --- New pricing helpers (points-based, broker-safe) ---

double ComputeLevelDistancePoints(const SignalParams &signal_params,
                                  const int level_index)
{
  double base_pts = signal_params.grid_base_distance_points;
  if(base_pts <= 0.0)
    return 0.0;
  double mult = Grid_Exponential_Multiplier;
  if(mult <= 0.0)
    mult = 1.0;
  double distance_pts = base_pts * MathPow(mult, (double)level_index);
  distance_pts = EnforceBrokerDistance(g_symbol_constraints, distance_pts);
  return distance_pts;
}

double ResolveGridLevelDistancePoints(const SignalParams &signal_params,
                                      const GridOrderState &state)
{
  if(Grid_Base_Strategy_Type == FIB_LEVEL_RANGE)
  {
    double fib_level_price = 0.0;
    if(!ResolveFibonacciGridLevelPrice(signal_params, state.level_index, fib_level_price))
      return signal_params.grid_base_distance_points;

    double entry_price = state.entry_reference_price;
    if(entry_price <= 0.0)
      entry_price = signal_params.grid_entry_reference_price;
    if(entry_price <= 0.0)
      entry_price = signal_params.entry_price;

    double point_size = GridResolvePointSize();
    if(point_size <= 0.0 || entry_price <= 0.0)
      return 0.0;

    double distance_pts = MathAbs(entry_price - fib_level_price) / point_size;
    distance_pts = EnforceBrokerDistance(g_symbol_constraints, distance_pts);
    return distance_pts;
  }

  return ComputeLevelDistancePoints(signal_params, state.level_index);
}

double ComputeEntryReferencePrice(const SignalParams &signal_params,
                                  const GridOrderState &state)
{
  double point_size = GridResolvePointSize();
  double entry_side = GridCurrentPriceForDirection(signal_params.signal_type, true);
  double offset_pts = signal_params.grid_entry_offset_points;
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
  double point_size = GridResolvePointSize();
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

bool GridFindLatestFilledOrder(const SignalParams &signal_params,
                               GridOrderState &state_out)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return false;

  for(int idx = total_levels - 1; idx >= 0; idx--)
  {
    GridOrderState state = signal_params.grid_orders[idx];
    if(state.level_index < 0)
      continue;
    if(state.entry_price <= 0.0)
      continue;
    if(state.status == GRID_ORDER_INACTIVE ||
       state.status == GRID_ORDER_WAITING ||
       state.status == GRID_ORDER_STOP_TRAILING_ACTIVE)
      continue;
    state_out = state;
    return true;
  }

  return false;
}

bool GridSignalHasExecutedLevel(const SignalParams &signal_params)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int idx = 0; idx < total_levels; idx++)
  {
    GridOrderState state = signal_params.grid_orders[idx];
    if(state.entry_price <= 0.0)
      continue;
    if(state.status == GRID_ORDER_ACTIVE ||
       state.status == GRID_ORDER_COMPLETED)
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

bool ResolveFibonacciEntryPercent(const SignalParams &signal_params,
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

bool ResolveFibonacciEntryRange(const SignalParams &signal_params,
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
  if(!ResolveFibonacciEntryPercent(signal_params,
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

  if(!StrategyContextUsesBreakoutCompoundMode(signal_params.strategy_context))
    return false;

  return g_structure_fibo_config.valid;
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

bool ResolveGridTraversalForLevel(const SignalParams &signal_params,
                                  const double entry_percent,
                                  const int level_index,
                                  double &start_percent_out,
                                  int &steps_out,
                                  bool &return_anchor_only_out,
                                  double &anchor_percent_out)
{
  start_percent_out = entry_percent;
  steps_out = signal_params.fib_level_offset_steps + level_index;
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
  steps_out = signal_params.fib_level_offset_steps + (level_index - 1);
  if(steps_out <= 0)
    steps_out = 1;

  return true;
}

bool ResolveFibonacciGridLevelPercent(const SignalParams &signal_params,
                                      const int level_index,
                                      double &level_percent_out)
{
  level_percent_out = 0.0;

  if(!g_structure_fibo_config.valid || !g_structure_fibo_config.cycle_valid)
    return false;

  double entry_price = signal_params.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.grid_entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveFibonacciEntryPercent(signal_params,
                                   entry_price,
                                   entry_percent,
                                   peak_price,
                                   bottom_price,
                                   current_is_bottom))
    return false;

  double start_percent = entry_percent;
  int steps = signal_params.fib_level_offset_steps + level_index;
  bool return_anchor_only = false;
  double anchor_percent = 0.0;
  if(!ResolveGridTraversalForLevel(signal_params,
                                   entry_percent,
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
  int step_dir = ResolveFibonacciStepDirection(signal_params.signal_type, current_is_bottom);
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

bool ResolveFibonacciGridLevelPrice(const SignalParams &signal_params,
                                    const int level_index,
                                    double &price_out)
{
  price_out = 0.0;
  if(!g_structure_fibo_config.valid || !g_structure_fibo_config.cycle_valid)
    return false;

  double entry_price = signal_params.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.grid_entry_reference_price;
  if(entry_price <= 0.0)
    return false;

  double entry_percent = 0.0;
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveFibonacciEntryPercent(signal_params,
                                   entry_price,
                                   entry_percent,
                                   peak_price,
                                   bottom_price,
                                   current_is_bottom))
    return false;

  double start_percent = entry_percent;
  int steps = signal_params.fib_level_offset_steps + level_index;
  bool return_anchor_only = false;
  double anchor_percent = 0.0;
  if(!ResolveGridTraversalForLevel(signal_params,
                                   entry_percent,
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
  int step_dir = ResolveFibonacciStepDirection(signal_params.signal_type, current_is_bottom);
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

bool ResolveFibonacciGridBaseDistance(const SignalParams &signal_params,
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
  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  if(!ResolveFibonacciEntryPercent(signal_params,
                                   entry_price,
                                   entry_percent,
                                   peak_price,
                                   bottom_price,
                                   current_is_bottom))
    return false;

  int step_dir = ResolveFibonacciStepDirection(signal_params.signal_type, current_is_bottom);

  double point_size = GridResolvePointSize();
  if(point_size <= 0.0)
    return false;

  int total_levels = ArraySize(g_structure_fibo_config.levels);
  if(total_levels < 2)
    return false;

  double required_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);
  int max_steps = total_levels + 10;

  if(SignalUsesBreakoutLimitAnchoring(signal_params))
  {
    double anchored_percent = 0.0;
    if(!ResolveBreakoutLimitOppositeEndpointPercent(entry_percent, anchored_percent))
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
                                                     entry_percent,
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
                                                 entry_percent,
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

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
