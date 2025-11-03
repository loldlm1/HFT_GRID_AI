//+------------------------------------------------------------------+
//|                               grid_order_controller.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

#include "../../microservices/utils/money_functions.mqh"

extern double g_bid;
extern double g_ask;
extern double g_points_spread;
extern double Max_Spread;

void InitializeGridOrdersForSignal(SignalParams &signal_params);
void UpdateGridLifecycle(SignalParams &signal_params);
bool IsGridSignalComplete(const SignalParams &signal_params);

// ── Internal helpers ──────────────────────────────────────────────

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

double GridCurrentPriceForDirection(const SignalTypes direction, const bool use_entry_side)
{
  if(direction == BULLISH)
    return use_entry_side ? g_ask : g_bid;
  return use_entry_side ? g_bid : g_ask;
}

bool GridGuardrailsAllowOrder(const double normalized_volume)
{
  if(g_points_spread > Max_Spread)
    return false;

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

  return (free_margin >= required_margin);
}

// ── Lifecycle helpers ─────────────────────────────────────────────

void GridActivateLevel(const SignalTypes direction,
                       GridOrderState &order_state,
                       const GridLevelPlan &level_plan,
                       const double pending_price)
{
  order_state.status             = GRID_ORDER_ACTIVE;
  order_state.entry_price        = GridCurrentPriceForDirection(direction, true);
  if(order_state.entry_price <= 0.0)
    order_state.entry_price = pending_price;
  order_state.last_action_time   = TimeCurrent();
  order_state.last_pending_price = pending_price;
  order_state.trailing_points    = level_plan.trailing_points;
}

bool GridCheckStopHit(const SignalTypes direction,
                      const GridOrderState &order_state)
{
  if(order_state.stop_loss_price <= 0.0)
    return false;

  double current_close = GridCurrentPriceForDirection(direction, false);

  if(direction == BULLISH)
    return (current_close <= order_state.stop_loss_price);
  return (current_close >= order_state.stop_loss_price);
}

bool GridCheckTakeProfitHit(const SignalTypes direction,
                            const GridOrderState &order_state)
{
  if(order_state.take_profit_price <= 0.0)
    return false;

  double current_close = GridCurrentPriceForDirection(direction, false);

  if(direction == BULLISH)
    return (current_close >= order_state.take_profit_price);
  return (current_close <= order_state.take_profit_price);
}

void GridUpdateTrailingStop(const SignalTypes direction,
                            GridOrderState &order_state,
                            const GridLevelPlan &level_plan,
                            const double point_size)
{
  if(level_plan.trailing_points <= 0.0 || order_state.take_profit_price <= 0.0)
    return;

  double trailing_distance = level_plan.trailing_points * point_size;
  double current_close     = GridCurrentPriceForDirection(direction, false);

  if(direction == BULLISH)
  {
    if(current_close <= order_state.entry_price)
      return;

    double candidate_sl = current_close - trailing_distance;
    if(candidate_sl > order_state.stop_loss_price)
      order_state.stop_loss_price = candidate_sl;
    return;
  }

  if(current_close >= order_state.entry_price)
    return;

  double candidate_sl = current_close + trailing_distance;
  if(order_state.stop_loss_price <= 0.0 || candidate_sl < order_state.stop_loss_price)
    order_state.stop_loss_price = candidate_sl;
}

void GridFinalizeLevel(const SignalTypes direction,
                       GridOrderState &order_state,
                       const double point_size)
{
  double current_close = GridCurrentPriceForDirection(direction, false);
  double entry_price   = order_state.entry_price;
  if(point_size <= 0.0 || entry_price <= 0.0)
  {
    order_state.realized_points = 0.0;
    order_state.status          = GRID_ORDER_COMPLETED;
    order_state.last_action_time = TimeCurrent();
    return;
  }

  double point_delta = 0.0;
  if(direction == BULLISH)
    point_delta = (current_close - entry_price) / point_size;
  else
    point_delta = (entry_price - current_close) / point_size;

  order_state.realized_points = point_delta;
  order_state.status          = GRID_ORDER_COMPLETED;
  order_state.last_action_time = TimeCurrent();
}

// ── Public API ─────────────────────────────────────────────────────

void InitializeGridOrdersForSignal(SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return;

  ArrayResize(signal_params.grid_orders, 0);
  int total_levels = ArraySize(signal_params.grid_plan.levels);
  ArrayResize(signal_params.grid_orders, total_levels);

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = GridOrderState();
    state.level_index     = i;
    state.status          = GRID_ORDER_WAITING;
    state.trailing_points = signal_params.grid_plan.levels[i].trailing_points;
    signal_params.grid_orders[i] = state;
  }
}

void GridEnsureOrderArrayPrepared(SignalParams &signal_params)
{
  int levels_total  = ArraySize(signal_params.grid_plan.levels);
  int current_total = ArraySize(signal_params.grid_orders);
  if(current_total == levels_total)
    return;

  ArrayResize(signal_params.grid_orders, levels_total);
  for(int i = 0; i < levels_total; i++)
  {
    GridOrderState state = GridOrderState();
    state.level_index     = i;
    state.status          = GRID_ORDER_WAITING;
    state.trailing_points = signal_params.grid_plan.levels[i].trailing_points;
    signal_params.grid_orders[i] = state;
  }
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return;

  GridEnsureOrderArrayPrepared(signal_params);

  double point_size      = GridResolvePointSize();
  SignalTypes direction  = signal_params.signal_type;
  double direction_mult  = GridResolveDirectionMultiplier(direction);
  double anchor_price    = GridCurrentPriceForDirection(direction, true);

  int levels_total = ArraySize(signal_params.grid_plan.levels);
  for(int i = 0; i < levels_total; i++)
  {
    GridLevelPlan level_plan = signal_params.grid_plan.levels[i];
    GridOrderState order_state = signal_params.grid_orders[i];

    double pending_price = anchor_price + direction_mult * level_plan.pending_order_points * point_size;

    double stop_price = 0.0;
    if(level_plan.stop_loss_points > 0.0)
    {
      double offset = level_plan.stop_loss_points * point_size;
      stop_price = (direction == BULLISH) ? (pending_price - offset) : (pending_price + offset);
    }

    double take_profit_price = 0.0;
    if(level_plan.take_profit_points > 0.0)
    {
      double offset = level_plan.take_profit_points * point_size;
      take_profit_price = (direction == BULLISH) ? (pending_price + offset) : (pending_price - offset);
    }

    order_state.last_pending_price = pending_price;
    order_state.stop_loss_price    = stop_price;
    order_state.take_profit_price  = take_profit_price;
    order_state.trailing_points    = level_plan.trailing_points;

    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, level_plan.lot_size);

    if(order_state.status == GRID_ORDER_WAITING)
    {
      if(GridGuardrailsAllowOrder(normalized_volume))
      {
        order_state.status = GRID_ORDER_PENDING;
        order_state.last_action_time = TimeCurrent();
      }
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_PENDING)
    {
      if(!GridGuardrailsAllowOrder(normalized_volume))
      {
        signal_params.grid_orders[i] = order_state;
        continue;
      }

      bool should_activate = false;
      if(direction == BULLISH)
        should_activate = (g_ask >= pending_price);
      else
        should_activate = (g_bid <= pending_price);

      if(should_activate)
      {
        GridActivateLevel(direction, order_state, level_plan, pending_price);
        signal_params.signal_state = OPENED;
      }

      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_ACTIVE)
    {
      bool stop_hit = GridCheckStopHit(direction, order_state);
      bool tp_hit   = (!stop_hit) && GridCheckTakeProfitHit(direction, order_state);

      if(stop_hit || tp_hit)
      {
        GridFinalizeLevel(direction, order_state, point_size);
        signal_params.grid_orders[i] = order_state;
        continue;
      }

      GridUpdateTrailingStop(direction, order_state, level_plan, point_size);
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    signal_params.grid_orders[i] = order_state;
  }
}

bool IsGridSignalComplete(const SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return true;

  int total_levels = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.status == GRID_ORDER_WAITING ||
       state.status == GRID_ORDER_PENDING ||
       state.status == GRID_ORDER_ACTIVE)
      return false;
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
