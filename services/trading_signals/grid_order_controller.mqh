//+------------------------------------------------------------------+
//|                               grid_order_controller.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

#include "../../microservices/utils/array_functions.mqh"
#include "../../microservices/utils/broker_constraints_helper.mqh"
#include "../../microservices/utils/money_functions.mqh"

extern SymbolTradingConstraints g_symbol_constraints;
extern double g_bid;
extern double g_ask;
extern double g_points_spread;
extern double g_decimal_digits;
extern int    g_magic_number;

void InitializeGridOrdersForSignal(SignalParams &signal_params);
void UpdateGridLifecycle(SignalParams &signal_params);
bool IsGridSignalComplete(const SignalParams &signal_params);

// ── Internal helpers ──────────────────────────────────────────────

double GridResolvePointSize()
{
  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001; // fallback for safety
  return point_size;
}

double GridNormalizePrice(double price)
{
  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  return NormalizeDouble(price, digits);
}

double GridResolveDirectionMultiplier(const SignalTypes direction)
{
  if(direction == BULLISH)
    return 1.0;
  if(direction == BEARISH)
    return -1.0;
  return 0.0;
}

string GridBuildOrderComment(const SignalTypes direction, const int level_index)
{
  string dir_label = (direction == BULLISH) ? "BUY" : "SELL";
  return StringFormat("GRID_%s_L%d", dir_label, level_index);
}

bool GridIsOrderTrackedByOtherLevel(const SignalParams &signal_params,
                                    const int current_index,
                                    const ulong ticket)
{
  int total = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < total; i++)
  {
    if(i == current_index)
      continue;
    if(signal_params.grid_orders[i].position_ticket == ticket ||
       signal_params.grid_orders[i].pending_order_ticket == ticket)
      return true;
  }
  return false;
}

bool GridGuardrailsAllowOrder(const SignalTypes direction,
                              const double volume,
                              const double price)
{
  if(g_points_spread > Max_Spread)
  {
    if(Enable_Logs)
      PrintFormat("Grid guardrail active: spread %.1f exceeds limit %.1f",
                  g_points_spread,
                  Max_Spread);
    return false;
  }

  double margin_required = 0.0;
  ENUM_ORDER_TYPE order_type = (direction == BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
  if(OrderCalcMargin(order_type, _Symbol, volume, price, margin_required))
  {
    double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(margin_required > 0.0 && free_margin <= margin_required)
    {
      if(Enable_Logs)
        PrintFormat("Grid guardrail active: free margin %.2f below requirement %.2f",
                    free_margin,
                    margin_required);
      return false;
    }
  }

  return true;
}

bool GridSendPendingOrder(const SignalParams &signal_params,
                          GridOrderState &order_state,
                          const GridLevelPlan &level_plan,
                          const double pending_price,
                          const double stop_loss,
                          const double take_profit)
{
  MqlTradeRequest request;
  MqlTradeResult  result;
  ZeroMemory(request);
  ZeroMemory(result);

  request.action       = TRADE_ACTION_PENDING;
  request.magic        = g_magic_number;
  request.symbol       = _Symbol;
  request.volume       = NormalizeVolumeForSymbol(_Symbol, level_plan.lot_size);
  request.price        = GridNormalizePrice(pending_price);
  request.sl           = (stop_loss > 0.0) ? GridNormalizePrice(stop_loss) : 0.0;
  request.tp           = (take_profit > 0.0) ? GridNormalizePrice(take_profit) : 0.0;
  request.type_time    = ORDER_TIME_GTC;
  request.deviation    = (int)MathCeil(Max_Spread);
  request.comment      = GridBuildOrderComment(signal_params.signal_type, level_plan.level_index);

  if(signal_params.signal_type == BULLISH)
    request.type = ORDER_TYPE_BUY_STOP;
  else
    request.type = ORDER_TYPE_SELL_STOP;

  request.type_filling = ORDER_FILLING_RETURN;

  if(!OrderSend(request, result))
  {
    if(Enable_Logs)
      PrintFormat("Grid order send failed (lvl %d) retcode=%d",
                  level_plan.level_index,
                  result.retcode);
    return false;
  }

  if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
  {
    if(Enable_Logs)
      PrintFormat("Grid order rejected (lvl %d) retcode=%d",
                  level_plan.level_index,
                  result.retcode);
    return false;
  }

  order_state.pending_order_ticket = result.order;
  order_state.status               = GRID_ORDER_PENDING;
  order_state.last_pending_price   = request.price;
  order_state.stop_loss_price      = request.sl;
  order_state.take_profit_price    = request.tp;
  order_state.trailing_points      = level_plan.trailing_points;
  order_state.last_action_time     = TimeCurrent();

  if(Enable_Logs)
  {
    PrintFormat("Grid pending order placed | lvl=%d | ticket=%I64d | price=%.5f | sl=%.5f | tp=%.5f",
                level_plan.level_index,
                order_state.pending_order_ticket,
                order_state.last_pending_price,
                order_state.stop_loss_price,
                order_state.take_profit_price);
  }

  return true;
}

bool GridModifyPendingOrder(GridOrderState &order_state,
                            const double pending_price,
                            const double stop_loss,
                            const double take_profit)
{
  if(order_state.pending_order_ticket == 0)
    return false;

  if(!OrderSelect(order_state.pending_order_ticket))
    return false;

  MqlTradeRequest request;
  MqlTradeResult  result;
  ZeroMemory(request);
  ZeroMemory(result);

  request.action = TRADE_ACTION_MODIFY;
  request.order  = order_state.pending_order_ticket;
  request.price  = GridNormalizePrice(pending_price);
  request.sl     = (stop_loss > 0.0) ? GridNormalizePrice(stop_loss) : 0.0;
  request.tp     = (take_profit > 0.0) ? GridNormalizePrice(take_profit) : 0.0;

  if(!OrderSend(request, result))
  {
    if(Enable_Logs)
      PrintFormat("Grid order modify failed (ticket=%I64d) retcode=%d",
                  order_state.pending_order_ticket,
                  result.retcode);
    return false;
  }

  if(result.retcode != TRADE_RETCODE_DONE)
  {
    if(Enable_Logs)
      PrintFormat("Grid order modify rejected (ticket=%I64d) retcode=%d",
                  order_state.pending_order_ticket,
                  result.retcode);
    return false;
  }

  order_state.last_pending_price = request.price;
  order_state.stop_loss_price    = request.sl;
  order_state.take_profit_price  = request.tp;
  order_state.last_action_time   = TimeCurrent();

  if(Enable_Logs)
  {
    PrintFormat("Grid pending order modified | ticket=%I64d | price=%.5f | sl=%.5f | tp=%.5f",
                order_state.pending_order_ticket,
                order_state.last_pending_price,
                order_state.stop_loss_price,
                order_state.take_profit_price);
  }

  return true;
}

bool GridUpdatePositionStops(const ulong position_ticket,
                             const double stop_loss,
                             const double take_profit)
{
  if(position_ticket == 0)
    return false;

  if(!PositionSelectByTicket(position_ticket))
    return false;

  MqlTradeRequest request;
  MqlTradeResult  result;
  ZeroMemory(request);
  ZeroMemory(result);

  request.action   = TRADE_ACTION_SLTP;
  request.position = position_ticket;
  request.symbol   = _Symbol;
  request.sl       = (stop_loss > 0.0) ? GridNormalizePrice(stop_loss) : 0.0;
  request.tp       = (take_profit > 0.0) ? GridNormalizePrice(take_profit) : 0.0;

  if(!OrderSend(request, result))
  {
    if(Enable_Logs)
      PrintFormat("Grid position modify failed (ticket=%I64d) retcode=%d",
                  position_ticket,
                  result.retcode);
    return false;
  }

  if(result.retcode != TRADE_RETCODE_DONE)
  {
    if(Enable_Logs)
      PrintFormat("Grid position modify rejected (ticket=%I64d) retcode=%d",
                  position_ticket,
                  result.retcode);
    return false;
  }

  if(Enable_Logs)
  {
    PrintFormat("Grid position updated | ticket=%I64d | sl=%.5f | tp=%.5f",
                position_ticket,
                request.sl,
                request.tp);
  }

  return true;
}

bool GridAcquirePositionTicket(SignalParams &signal_params,
                               GridOrderState &order_state,
                               const SignalTypes direction)
{
  if(order_state.position_ticket != 0)
  {
    if(PositionSelectByTicket(order_state.position_ticket))
      return true;
    order_state.position_ticket = 0;
  }

  int total_positions = PositionsTotal();
  for(int i = 0; i < total_positions; i++)
  {
    if(!PositionSelectByIndex(i))
      continue;

    string pos_symbol = PositionGetString(POSITION_SYMBOL);
    if(pos_symbol != _Symbol)
      continue;

    long magic = PositionGetInteger(POSITION_MAGIC);
    if((int)magic != g_magic_number)
      continue;

    long type = PositionGetInteger(POSITION_TYPE);
    if(direction == BULLISH && type != POSITION_TYPE_BUY)
      continue;
    if(direction == BEARISH && type != POSITION_TYPE_SELL)
      continue;

    ulong iter_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
    if(GridIsOrderTrackedByOtherLevel(signal_params, order_state.level_index, iter_ticket))
      continue;

    order_state.position_ticket      = iter_ticket;
    order_state.pending_order_ticket = 0;
    order_state.status               = GRID_ORDER_ACTIVE;
    order_state.last_action_time     = TimeCurrent();

    if(Enable_Logs)
    {
      PrintFormat("Grid position linked | lvl=%d | ticket=%I64d",
                  order_state.level_index,
                  order_state.position_ticket);
    }
    return true;
  }

  return false;
}

void GridUpdateTrailingForPosition(SignalParams &signal_params,
                                   GridOrderState &order_state,
                                   const GridLevelPlan &level_plan)
{
  if(order_state.position_ticket == 0)
    return;

  if(!PositionSelectByTicket(order_state.position_ticket))
  {
    order_state.position_ticket = 0;
    order_state.pending_order_ticket = 0;
    order_state.status          = GRID_ORDER_COMPLETED;
    return;
  }

  if(level_plan.trailing_points <= 0.0)
    return;

  double point_size = GridResolvePointSize();
  double trailing_distance = level_plan.trailing_points * point_size;
  double current_price = (signal_params.signal_type == BULLISH) ? g_bid : g_ask;
  double entry_price   = PositionGetDouble(POSITION_PRICE_OPEN);
  double stop_loss     = PositionGetDouble(POSITION_SL);
  double take_profit   = PositionGetDouble(POSITION_TP);

  if(signal_params.signal_type == BULLISH)
  {
    double move_distance = current_price - entry_price;
    if(move_distance <= trailing_distance)
      return;

    double desired_sl = current_price - trailing_distance;
    if(stop_loss >= desired_sl - 1e-6)
      return;

    desired_sl = GridNormalizePrice(desired_sl);
    if(GridUpdatePositionStops(order_state.position_ticket, desired_sl, take_profit))
    {
      order_state.stop_loss_price = desired_sl;
      order_state.last_action_time = TimeCurrent();
    }
    return;
  }

  double move_distance = entry_price - current_price;
  if(move_distance <= trailing_distance)
    return;

  double desired_sl = current_price + trailing_distance;
  if(stop_loss <= desired_sl + 1e-6 && stop_loss != 0.0)
    return;

  desired_sl = GridNormalizePrice(desired_sl);
  if(GridUpdatePositionStops(order_state.position_ticket, desired_sl, take_profit))
  {
    order_state.stop_loss_price = desired_sl;
    order_state.last_action_time = TimeCurrent();
  }
}

void GridEnsureOrderArrayPrepared(SignalParams &signal_params)
{
  int levels_total = ArraySize(signal_params.grid_plan.levels);
  int current_total = ArraySize(signal_params.grid_orders);
  if(current_total == levels_total)
    return;

  ArrayResize(signal_params.grid_orders, levels_total);
  for(int i = 0; i < levels_total; i++)
  {
    GridOrderState state = GridOrderState();
    state.level_index    = i;
    state.trailing_points = signal_params.grid_plan.levels[i].trailing_points;
    state.status         = GRID_ORDER_WAITING;
    signal_params.grid_orders[i] = state;
  }
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

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return;

  GridEnsureOrderArrayPrepared(signal_params);

  double point_size    = GridResolvePointSize();
  double min_distance  = MinBrokerDistancePoints(g_symbol_constraints) * point_size;
  double reference_bid = g_bid;
  double reference_ask = g_ask;
  double direction_mult = GridResolveDirectionMultiplier(signal_params.signal_type);

  int levels_total = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < levels_total; i++)
  {
    GridLevelPlan level_plan = signal_params.grid_plan.levels[i];
    GridOrderState order_state = signal_params.grid_orders[i];

    double anchor_price = (signal_params.signal_type == BULLISH) ? reference_ask : reference_bid;
    double desired_pending_price = anchor_price + direction_mult * level_plan.pending_order_points * point_size;

    if(signal_params.signal_type == BULLISH)
      desired_pending_price = MathMax(desired_pending_price, reference_ask + min_distance);
    else
      desired_pending_price = MathMin(desired_pending_price, reference_bid - min_distance);

    double desired_stop = 0.0;
    if(level_plan.stop_loss_points > 0.0)
    {
      double stop_offset = level_plan.stop_loss_points * point_size;
      if(signal_params.signal_type == BULLISH)
        desired_stop = desired_pending_price - stop_offset;
      else
        desired_stop = desired_pending_price + stop_offset;
    }

    double desired_tp = 0.0;
    if(level_plan.take_profit_points > 0.0)
    {
      double tp_offset = level_plan.take_profit_points * point_size;
      if(signal_params.signal_type == BULLISH)
        desired_tp = desired_pending_price + tp_offset;
      else
        desired_tp = desired_pending_price - tp_offset;
    }

    if(order_state.status == GRID_ORDER_WAITING)
    {
      double normalized_volume = NormalizeVolumeForSymbol(_Symbol, level_plan.lot_size);
      if(!GridGuardrailsAllowOrder(signal_params.signal_type, normalized_volume, desired_pending_price))
      {
        signal_params.grid_orders[i] = order_state;
        continue;
      }

      if(GridSendPendingOrder(signal_params, signal_params.grid_orders[i], level_plan, desired_pending_price, desired_stop, desired_tp))
        signal_params.signal_state = OPENED;

      continue;
    }

    if(order_state.status == GRID_ORDER_PENDING)
    {
      if(order_state.pending_order_ticket != 0 && OrderSelect(order_state.pending_order_ticket, SELECT_BY_TICKET))
      {
        bool should_modify = false;
        if(signal_params.signal_type == BULLISH)
        {
          if(desired_pending_price < order_state.last_pending_price - (min_distance / 2.0))
            should_modify = true;
        }
        else
        {
          if(desired_pending_price > order_state.last_pending_price + (min_distance / 2.0))
            should_modify = true;
        }

        if(should_modify)
          GridModifyPendingOrder(signal_params.grid_orders[i], desired_pending_price, desired_stop, desired_tp);
      }
      else
      {
        GridAcquirePositionTicket(signal_params, signal_params.grid_orders[i], signal_params.signal_type);
        if(signal_params.grid_orders[i].status != GRID_ORDER_ACTIVE)
        {
          signal_params.grid_orders[i].pending_order_ticket = 0;
          signal_params.grid_orders[i].status               = GRID_ORDER_COMPLETED;
        }
      }

      continue;
    }

    if(order_state.status == GRID_ORDER_ACTIVE)
    {
      if(!GridAcquirePositionTicket(signal_params, signal_params.grid_orders[i], signal_params.signal_type))
      {
        signal_params.grid_orders[i].status = GRID_ORDER_COMPLETED;
        continue;
      }

      GridUpdateTrailingForPosition(signal_params, signal_params.grid_orders[i], level_plan);
      continue;
    }

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
