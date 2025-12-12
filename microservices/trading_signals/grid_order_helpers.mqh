//+------------------------------------------------------------------+
//|                               microservices/trading_signals/... |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_

inline StrategyTrendModes GridResolveActiveRiskMode(const GridRiskTrendTimeframeSources source)
{
  switch(source)
  {
    case GRID_RISK_TF_STRATEGY:
      return Strategy_Base_Trend_Mode;
    case GRID_RISK_TF_TREND:
      return Strategy_Trend_Trend_Mode;
    case GRID_RISK_TF_MACRO:
      return Strategy_Macro_Trend_Mode;
    case GRID_RISK_TF_SESSION:
      return Strategy_Session_Trend_Mode;
  }
  return Strategy_Trend_Trend_Mode;
}

inline StrategyTrendModes GridResolveActiveRiskMode()
{
  return GridResolveActiveRiskMode(Grid_Risk_Timeframe_Source);
}

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

ENUM_TIMEFRAMES GridResolveTrailingStrategyTimeframe()
{
  if(Trailing_Indicator_Timeframe > 0)
    return Trailing_Indicator_Timeframe;
  int total = ArraySize(Strategy_TF_List);
  if(total > 0)
    return Strategy_TF_List[0];
  return Strategy_Timeframe;
}

ENUM_TIMEFRAMES GridResolveRiskTrendTimeframe()
{
  if(Risk_Trend_Timeframe > 0)
    return Risk_Trend_Timeframe;
  int total = ArraySize(Strategy_TF_List);
  if(total > 0)
    return Strategy_TF_List[0];
  return Strategy_Timeframe;
}

bool GridResolveAlligatorBufferPrice(const ENUM_TIMEFRAMES target_tf,
                                     const int buffer_index,
                                     double &price_out)
{
  price_out = 0.0;

  int total_handles = ArraySize(ExtAlligatorIndicatorsHandle);
  if(total_handles <= 0)
    return false;

  for(int i = 0; i < total_handles; i++)
  {
    if(ExtAlligatorIndicatorsHandle[i].indicator_timeframe != target_tf)
      continue;

    double buffer[];
    if(CopyBuffer(ExtAlligatorIndicatorsHandle[i].indicator_handle,
                  buffer_index,
                  0,
                  1,
                  buffer) <= 0)
      continue;

    double candidate = buffer[0];
    if(candidate > 0.0)
    {
      price_out = NormalizeDouble(candidate, _Digits);
      return true;
    }
  }

  return false;
}

bool GridResolveAlligatorLipsTrailingPrice(const SignalParams &signal_params,
                                           double &price_out)
{
  ENUM_TIMEFRAMES target_tf = GridResolveTrailingStrategyTimeframe();
  return GridResolveAlligatorBufferPrice(target_tf, 2, price_out);
}

bool GridResolveAlligatorRiskReferencePrice(const ENUM_TIMEFRAMES target_tf,
                                            double &price_out)
{
  int buffer_index = (Grid_Risk_Alligator_Reference == GRID_RISK_REF_TEETH) ? 1 : 0;
  return GridResolveAlligatorBufferPrice(target_tf, buffer_index, price_out);
}

int GridAggressiveLotSplitCount()
{
  double splits = MathMax(1.0, Grid_Lot_Strategy_Size);
  int rounded = (int)MathRound(splits);
  if(rounded <= 0)
    rounded = 1;
  return rounded;
}

double GridResolveAggressiveLotSize(const SignalTypes direction)
{
  double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  if(free_margin <= 0.0)
    return 0.0;

  double price = GridCurrentPriceForDirection(direction, true);
  if(price <= 0.0)
    price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
  if(price <= 0.0)
    return 0.0;

  double margin_per_lot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
  if(margin_per_lot <= 0.0)
  {
    double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
    if(leverage <= 0.0)
      leverage = 1.0;
    margin_per_lot = (contract_size * price) / leverage;
  }

  if(margin_per_lot <= 0.0)
    return 0.0;

  double buffer = 0.995;
  double max_lots = (free_margin * buffer) / margin_per_lot;
  double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
  if(volume_max > 0.0 && max_lots > volume_max)
    max_lots = volume_max;

  int split_count = GridAggressiveLotSplitCount();
  double per_split = max_lots / (double)split_count;
  if(per_split <= 0.0)
    return 0.0;

  double normalized = NormalizeVolumeForSymbol(_Symbol, per_split);

  double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
  if(volume_min <= 0.0)
    volume_min = 0.01;

  double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
  if(volume_step <= 0.0)
    volume_step = volume_min;

  double required_margin = normalized * margin_per_lot;
  while(normalized > volume_min && required_margin > free_margin)
  {
    normalized -= volume_step;
    normalized = NormalizeVolumeForSymbol(_Symbol, normalized);
    required_margin = normalized * margin_per_lot;
  }

  if(required_margin > free_margin)
    return 0.0;

  return NormalizeVolumeForSymbol(_Symbol, normalized);
}

int GridResolveSarAlligatorBufferIndex()
{
  StrategyTrendModes risk_mode = GridResolveActiveRiskMode();
  if(TrendModeUsesTeethAlligator(risk_mode))
    return 2; // LIPS provides confirmation when teeth branch active
  if(TrendModeUsesAlligator(risk_mode))
    return 1; // TEETH when jaws branch active
  return -1;
}

bool GridSarEntryConditionReady(const SignalParams &signal_params)
{
  if(!signal_params.is_sar_signal)
    return true;

  int buffer_index = GridResolveSarAlligatorBufferIndex();
  if(buffer_index < 0)
    return true;

  ENUM_TIMEFRAMES target_tf = Strategy_TF_List[0];
  if(target_tf <= 0)
    target_tf = Strategy_Timeframe;

  double ma_price = 0.0;
  if(!GridResolveAlligatorBufferPrice(target_tf, buffer_index, ma_price))
    return false;
  if(ma_price <= 0.0)
    return false;

  double current_price = GridCurrentPriceForDirection(signal_params.signal_type, true);
  if(signal_params.signal_type == BEARISH)
    return current_price >= ma_price;
  if(signal_params.signal_type == BULLISH)
    return current_price <= ma_price;
  return false;
}

bool GridResolveTrailingStrategyPrice(const SignalParams &signal_params,
                                      double &price_out)
{
  price_out = 0.0;

  if(PandoraStrategyEnabled())
    return false;

  if(Grid_Trailing_Strategy_Mode == TRAILING_ATR_BASED)
  {
    ENUM_TIMEFRAMES tf = GridResolveTrailingStrategyTimeframe();
    GridBaseStrategyTypes channel_type = ResolveActiveChannelStrategy();
    GridChannelLineTypes line_type = (signal_params.signal_type == BULLISH)
                                       ? GRID_CHANNEL_LINE_RESISTANCE
                                       : GRID_CHANNEL_LINE_SUPPORT;
    return GridResolveChannelLinePrice(channel_type, line_type, tf, price_out, 0);
  }

  if(Grid_Trailing_Strategy_Mode == TRAILING_LIPS_MA)
    return GridResolveAlligatorLipsTrailingPrice(signal_params, price_out);

  return false;
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
  state.final_take_profit_price = 0.0;
  state.trailing_price     = 0.0;
  state.next_level_price   = template_state.next_level_price;
  state.last_action_time   = 0;
  state.is_trailing_active = false;
  state.tp_reached         = false;
  state.break_even_active  = false;
  state.break_even_price   = 0.0;
  state.partial_take_executed = false;
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

double GetGridStopReferencePrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
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
  double grid_atr_fallback_price = 0;
  double grid_base_entry_price   = grid_order_state.entry_reference_price;
  double grid_next_level_price   = grid_order_state.next_level_price;
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
  double grid_atr_fallback_price      = 0;
  int    grid_level_index             = grid_order_state.level_index;
  double grid_base_entry_price        = grid_order_state.entry_reference_price;
  double grid_take_profit_price       = grid_order_state.take_profit_price;
  // Per-level TP span based on exponential distance
  double level_distance_pts           = ComputeLevelDistancePoints(signal_params, grid_order_state.level_index);
  double tp_span_pts;
  if(Grid_Points_TP > 0.0)
    tp_span_pts = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_TP);
  else
    tp_span_pts = level_distance_pts * (Grid_TP_Percent / 100.0);

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

  if(Grid_Enable_Robust_TP)
    EnsureGridTakeProfitRobustness(
      direction, signal_params, grid_level_index, grid_raw_tp_price
    );

  if(Grid_Enable_Scalper_TP)
    EnsureGridTakeProfitScalper(
      direction, signal_params, grid_level_index, grid_raw_tp_price
    );

  if(Grid_Enable_Aggressive_TP)
    EnsureGridTakeProfitAggressive(
      signal_params, grid_level_index, false, grid_raw_tp_price
    );

  return grid_raw_tp_price;
}

double GetGridTakeProfitFinalPrice(SignalTypes direction, SignalParams &signal_params, GridOrderState &grid_order_state)
{
  double grid_raw_tp_price            = 0;
  double grid_atr_fallback_price      = 0;
  int    grid_level_index             = grid_order_state.level_index;
  double grid_base_entry_price        = grid_order_state.entry_reference_price;
  double grid_final_take_profit_price = grid_order_state.final_take_profit_price;
  // Per-level final TP span based on exponential distance
  double level_distance_pts           = ComputeLevelDistancePoints(signal_params, grid_order_state.level_index);
  double final_span_pts               = level_distance_pts * (Grid_Final_TP_Percent / 100.0);

  if(direction == BULLISH)
  {
    grid_raw_tp_price = grid_base_entry_price + (final_span_pts / g_decimal_digits);

    if(grid_raw_tp_price > grid_final_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE ROCKET
    } else {
      grid_raw_tp_price = grid_final_take_profit_price == 0 ? grid_raw_tp_price : grid_final_take_profit_price;
    }
  }
  if(direction == BEARISH)
  {
    grid_raw_tp_price = grid_base_entry_price - (final_span_pts / g_decimal_digits);

    if(grid_raw_tp_price < grid_final_take_profit_price)
    {
      grid_raw_tp_price = grid_raw_tp_price; // FOLLOWS THE PRICE FALLS
    } else {
      grid_raw_tp_price = grid_final_take_profit_price == 0 ? grid_raw_tp_price : grid_final_take_profit_price;
    }
  }

  if(Grid_Enable_Robust_TP)
    EnsureGridTakeProfitRobustness(
      direction, signal_params, grid_level_index, grid_raw_tp_price
    );

  if(Grid_Enable_Aggressive_TP)
    EnsureGridTakeProfitAggressive(
      signal_params, grid_level_index, true, grid_raw_tp_price
    );

  return grid_raw_tp_price;
}

void EnsureGridTakeProfitRobustness(
  SignalTypes direction, SignalParams &signal_params, int grid_level_index, double &grid_raw_tp_price
) {
  // ENSURE TP IS IN A ROBUST DISTANCE FROM ENTRY
  if(grid_level_index > 0)
  {
    double initial_grid_price = signal_params.grid_orders[0].entry_price;
    double latest_grid_price  = signal_params.grid_orders[grid_level_index - 1].entry_price;

    if(direction == BULLISH)
    {
      if(grid_raw_tp_price < latest_grid_price)
        grid_raw_tp_price = latest_grid_price;
      if(grid_raw_tp_price > initial_grid_price)
        grid_raw_tp_price = initial_grid_price;
    }
    if(direction == BEARISH)
    {
      if(grid_raw_tp_price > latest_grid_price)
        grid_raw_tp_price = latest_grid_price;
      if(grid_raw_tp_price < initial_grid_price)
        grid_raw_tp_price = initial_grid_price;
    }
  }
}

void EnsureGridTakeProfitScalper(
  SignalTypes direction, SignalParams &signal_params, int grid_level_index, double &grid_raw_tp_price
) {
  // ENSURE TP IS IN A ROBUST DISTANCE FROM ENTRY
  if(grid_level_index > 0)
  {
    double initial_grid_price = signal_params.grid_orders[0].entry_price;
    double latest_grid_price  = signal_params.grid_orders[grid_level_index - 1].entry_price;

    if(direction == BULLISH) grid_raw_tp_price = latest_grid_price;
    if(direction == BEARISH) grid_raw_tp_price = latest_grid_price;
  }
}

void EnsureGridTakeProfitAggressive(
  SignalParams &signal_params, int grid_level_index, bool is_final_tp, double &grid_raw_tp_price
) {
  // ENSURE TP IS IN A ROBUST DISTANCE FROM ENTRY
  if(grid_level_index > 0)
  {
    double initial_grid_price    = signal_params.grid_orders[0].entry_price;
    double initial_grid_tp       = signal_params.grid_orders[0].take_profit_price;
    double initial_grid_final_tp = signal_params.grid_orders[0].final_take_profit_price;

    if(!is_final_tp) grid_raw_tp_price = initial_grid_tp;
    if(is_final_tp)  grid_raw_tp_price = initial_grid_final_tp;
  }
}

double UpdateTrailingTP(SignalParams &signal_params, GridOrderState &order_state)
{
  double current_price       = GridCurrentPriceForDirection(signal_params.signal_type, false);
  double digit_scale         = (g_decimal_digits > 0.0) ? g_decimal_digits : 1.0;
  double trailing_span_pts   = MathAbs(order_state.take_profit_price - order_state.entry_price) * digit_scale;
  double offset_pts          = trailing_span_pts * (Grid_Trailing_TP_Percent / 100.0);
  double offset_price        = offset_pts / digit_scale;
  double grid_trailing_price = order_state.trailing_price;
  double indicator_price     = 0.0;
  bool   indicator_mode      = ((Grid_Trailing_Strategy_Mode == TRAILING_ATR_BASED) ||
                                (Grid_Trailing_Strategy_Mode == TRAILING_LIPS_MA)) &&
                               GridResolveTrailingStrategyPrice(signal_params, indicator_price);
  bool   step_mode           = (Grid_Trailing_Strategy_Mode == TRAILING_STEP);

  if(step_mode)
  {
    double point_size = GridResolvePointSize();
    if(point_size <= 0.0)
      point_size = 0.0001;

    double step_points = offset_pts;
    if(step_points <= 0.0)
      step_points = EnforceBrokerDistance(g_symbol_constraints);
    double step_price = step_points / digit_scale;

    double current_stop = grid_trailing_price;
    if(signal_params.signal_type == BULLISH)
    {
      double base_stop = current_price - step_price;
      if(current_stop <= 0.0)
        return MathMax(base_stop, 0.0);

      double delta = current_price - current_stop;
      if(delta >= step_price)
      {
        double candidate = current_price - step_price;
        return MathMax(candidate, current_stop);
      }
      return current_stop;
    }

    if(signal_params.signal_type == BEARISH)
    {
      double base_stop = current_price + step_price;
      if(current_stop <= 0.0)
        return base_stop;

      double delta = current_stop - current_price;
      if(delta >= step_price)
      {
        double candidate = current_price + step_price;
        return MathMin(candidate, current_stop);
      }
      return current_stop;
    }
  }

  if(indicator_mode && indicator_price > 0.0)
  {
    double broker_price = EnforceBrokerDistance(g_symbol_constraints) / digit_scale;
    if(broker_price < 0.0)
      broker_price = 0.0;

    if(signal_params.signal_type == BULLISH)
    {
      double candidate = indicator_price + offset_price;
      if(broker_price > 0.0 && grid_trailing_price <= 0.0)
      {
        double cap_price = current_price - broker_price;
        if(cap_price > 0.0 && candidate > cap_price)
          candidate = cap_price;
      }

      if(grid_trailing_price > 0.0)
        candidate = MathMax(candidate, grid_trailing_price);
      return candidate;
    }
    if(signal_params.signal_type == BEARISH)
    {
      double candidate = indicator_price - offset_price;
      if(broker_price > 0.0 && grid_trailing_price <= 0.0)
      {
        double floor_price = current_price + broker_price;
        if(floor_price > 0.0 && candidate < floor_price)
          candidate = floor_price;
      }

      if(grid_trailing_price > 0.0)
        candidate = MathMin(candidate, grid_trailing_price);
      return candidate;
    }
  }

  double safe_fallback_price = 0.0;
  double candidate           = 0.0;

  if(signal_params.signal_type == BULLISH)
  {
    safe_fallback_price = current_price - (EnforceBrokerDistance(g_symbol_constraints) / digit_scale);
    candidate           = current_price - (offset_pts / digit_scale);

    if(candidate > grid_trailing_price)
      return candidate;
    return grid_trailing_price == 0 ? safe_fallback_price : grid_trailing_price;
  }
  if(signal_params.signal_type == BEARISH)
  {
    safe_fallback_price = current_price + (EnforceBrokerDistance(g_symbol_constraints) / digit_scale);
    candidate           = current_price + (offset_pts / digit_scale);

    if(candidate < grid_trailing_price)
      return candidate;
    return grid_trailing_price == 0 ? candidate : grid_trailing_price;
  }

  return safe_fallback_price;
}

void ResetGridOrderPricesByDirection(SignalParams &signal_params, int grid_order_level)
{
  if(signal_params.signal_type == BULLISH)
  {
    signal_params.grid_orders[grid_order_level].entry_reference_price   = DBL_MAX;
    signal_params.grid_orders[grid_order_level].next_level_price        = DBL_MAX;
    signal_params.grid_orders[grid_order_level].take_profit_price       = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].final_take_profit_price = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].trailing_price          = -DBL_MAX;
  }
  if(signal_params.signal_type == BEARISH)
  {
    signal_params.grid_orders[grid_order_level].entry_reference_price   = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].next_level_price        = -DBL_MAX;
    signal_params.grid_orders[grid_order_level].take_profit_price       = DBL_MAX;
    signal_params.grid_orders[grid_order_level].final_take_profit_price = DBL_MAX;
    signal_params.grid_orders[grid_order_level].trailing_price          = DBL_MAX;
  }
  signal_params.grid_orders[grid_order_level].break_even_active = false;
  signal_params.grid_orders[grid_order_level].break_even_price  = 0.0;
  signal_params.grid_orders[grid_order_level].partial_take_executed = false;
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

double GridCollectSignalFloatingProfit(const SignalParams &signal_params)
{
  double cumulative = 0.0;
  int total_levels = ArraySize(signal_params.grid_orders);
  for(int idx = 0; idx < total_levels; idx++)
  {
    GridOrderState state = signal_params.grid_orders[idx];
    if(state.position_ticket <= 0)
      continue;
    if(!PositionSelectByTicket(state.position_ticket))
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    cumulative += PositionGetDouble(POSITION_PROFIT);
  }
  return cumulative;
}

double GridCollectSignalFloatingProfitWithoutHedge(const SignalParams &signal_params)
{
  double cumulative = 0.0;
  int total_levels = ArraySize(signal_params.grid_orders);
  ulong hedge_ticket = signal_params.hedge_position_ticket;

  for(int idx = 0; idx < total_levels; idx++)
  {
    GridOrderState state = signal_params.grid_orders[idx];
    if(state.position_ticket <= 0)
      continue;
    if(state.position_ticket == hedge_ticket && hedge_ticket > 0)
      continue;
    if(!PositionSelectByTicket(state.position_ticket))
      continue;
    if(PositionGetInteger(POSITION_MAGIC) != g_magic_number)
      continue;
    if(PositionGetString(POSITION_SYMBOL) != _Symbol)
      continue;
    cumulative += PositionGetDouble(POSITION_PROFIT);
  }
  return cumulative;
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
       state.status == GRID_ORDER_TP_TRAILING_ACTIVE ||
       state.status == GRID_ORDER_COMPLETED)
      return true;
  }
  return false;
}

bool GridSignalChannelGuardSatisfied(const SignalParams &signal_params,
                                     const double entry_reference_price,
                                     double &distance_points,
                                     double &required_points,
                                     double &reference_price)
{
  if(PandoraStrategyEnabled())
    return true;

  distance_points = 0.0;
  reference_price = 0.0;
  required_points = EnforceBrokerDistance(g_symbol_constraints, Grid_Points_Range_Setup);

  if(!GridStrategyUsesChannelIndicator() || required_points <= 0.0)
    return true;
  if(entry_reference_price <= 0.0)
    return true;

  GridBaseStrategyTypes channel_type = ResolveActiveChannelStrategy();

  if(!GridResolveChannelGuardPoints(channel_type,
                                    signal_params.signal_type,
                                    Strategy_Timeframe,
                                    entry_reference_price,
                                    distance_points,
                                    reference_price,
                                    1))
    return true;

  return (distance_points >= required_points);
}

double ResolveStochStructureDistancePoints(const SignalParams &signal_params,
                                            const double entry_reference_price)
{
  if(signal_params.grid_initialized &&
     ArraySize(signal_params.grid_orders) > 0 &&
     signal_params.grid_base_distance_points > 0.0)
  {
    return EnforceBrokerDistance(g_symbol_constraints,
                                 signal_params.grid_base_distance_points);
  }

  double structure_price = 0.0;
  datetime structure_time = 0;
  bool structure_valid = false;
  StochasticMarketStructure stoch;

  switch(signal_params.strategy_context)
  {
    case CONTEXT_SLOT_TREND:
      structure_valid = signal_params.trend_structure_valid;
      stoch = signal_params.trend_structure_data;
      break;
    case CONTEXT_SLOT_MACRO:
      structure_valid = signal_params.macro_structure_valid;
      stoch = signal_params.macro_structure_data;
      break;
    case CONTEXT_SLOT_SESSION:
      structure_valid = signal_params.session_structure_valid;
      stoch = signal_params.session_structure_data;
      break;
    case CONTEXT_SLOT_BASE:
    default:
      structure_valid = signal_params.base_structure_valid;
      stoch = signal_params.base_structure_data;
      break;
  }

  if(structure_valid)
  {
    OscillatorStructureTypes types[4] = {stoch.first_structure_type,
                                         stoch.second_structure_type,
                                         stoch.third_structure_type,
                                         stoch.fourth_structure_type};
    double prices[4] = {stoch.first_structure_price,
                        stoch.second_structure_price,
                        stoch.third_structure_price,
                        stoch.fourth_structure_price};
    datetime times[4] = {stoch.first_structure_time,
                        stoch.second_structure_time,
                        stoch.third_structure_time,
                        stoch.fourth_structure_time};

    // Prefer the latest prior swing (skip current index 0), then fall back to current.
    for(int i = 1; i < 4; i++)
    {
      if(signal_params.signal_type == BULLISH &&
         (types[i] == OSCILLATOR_STRUCTURE_LL || types[i] == OSCILLATOR_STRUCTURE_LH) &&
         prices[i] > 0.0 && prices[i] < g_ask)
      {
        structure_price = prices[i];
        structure_time = times[i];
        break;
      }
      if(signal_params.signal_type == BEARISH &&
         (types[i] == OSCILLATOR_STRUCTURE_HH || types[i] == OSCILLATOR_STRUCTURE_HL) &&
         prices[i] > 0.0 && prices[i] > g_bid)
      {
        structure_price = prices[i];
        structure_time = times[i];
        break;
      }
    }
  }

  if(structure_price <= 0.0)
    return 0.0;

  double point_size = GridResolvePointSizeSafe();
  if(point_size <= 0.0)
    return 0.0;

  double distance_points = MathAbs(structure_price - entry_reference_price) / point_size;
  return EnforceBrokerDistance(g_symbol_constraints, distance_points);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_HELPERS_MQH_
