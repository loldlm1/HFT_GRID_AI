//+------------------------------------------------------------------+
//|                               grid_order_controller.mqh          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

#include <Trade/Trade.mqh>
#include "../../microservices/utils/money_functions.mqh"
#include "../../microservices/utils/file_logger.mqh"

extern double g_bid;
extern double g_ask;
extern double g_points_spread;
extern int    g_magic_number;
extern CTrade g_position;

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

double GridCurrentPriceForDirection(const SignalTypes direction,
                                    const bool use_entry_side)
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

void GridLogEvent(const string label,
                  const SignalParams &signal_params,
                  const GridOrderState &order_state,
                  const GridLevelPlan &level_plan)
{
  if(!Enable_File_Logs)
    return;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string message = StringFormat("dir=%s|level=%d|status=%s|stop=%.5f|entry=%.5f|tp=%.5f|next=%.5f|anchor=%.5f",
                                direction,
                                order_state.level_index,
                                EnumToString(order_state.status),
                                order_state.stop_loss_price,
                                order_state.entry_price,
                                order_state.take_profit_price,
                                order_state.next_level_price,
                                order_state.anchor_price);
  AppendTimestampedLog("query_debug.txt", label, message);
}

string GridComposeLevelComment(const SignalParams &signal_params,
                               const GridOrderState &order_state)
{
  string direction_label = (signal_params.signal_type == BULLISH) ? "B" : "S";
  string time_label      = IntegerToString((long)signal_params.entry_time);
  return StringFormat("GRID_%s_%s_L%d", direction_label, time_label, order_state.level_index);
}

void GridComposeFrontendState(SignalParams &signal_params)
{
  int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
  if(digits <= 0)
    digits = 5;

  string json = "{";
  json += "\"direction\":\"";
  json += EnumToString(signal_params.signal_type);
  json += "\",\"levels\":[";

  int levels_total = ArraySize(signal_params.grid_orders);
  for(int i = 0; i < levels_total; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(i > 0)
      json += ",";

    json += "{\"index\":";
    json += IntegerToString(state.level_index);
    json += ",\"status\":\"";
    json += EnumToString(state.status);
    json += "\",\"anchor\":";
    json += DoubleToString(state.anchor_price, digits);
    json += ",\"pending\":";
    json += DoubleToString(state.last_pending_price, digits);
    json += ",\"entry\":";
    json += DoubleToString(state.entry_price, digits);
    json += ",\"stop\":";
    json += DoubleToString(state.stop_loss_price, digits);
    json += ",\"tp\":";
    json += DoubleToString(state.take_profit_price, digits);
    json += ",\"tp_final\":";
    json += DoubleToString(state.final_take_profit_price, digits);
    json += ",\"next\":";
    json += DoubleToString(state.next_level_price, digits);
    json += "}";
  }

  json += "],\"stats\":{";
  json += "\"max_favorable\":";
  json += DoubleToString(signal_params.grid_stats.max_favorable_points, 1);
  json += ",\"max_adverse\":";
  json += DoubleToString(signal_params.grid_stats.max_adverse_points, 1);
  json += ",\"completed\":";
  json += IntegerToString(signal_params.grid_stats.completed_levels);
  json += ",\"pf\":";
  json += DoubleToString(signal_params.grid_stats.ProfitFactor(), 2);
  json += ",\"activation_time\":";
  json += IntegerToString((long)signal_params.grid_stats.activation_time);
  json += ",\"last_update\":";
  json += IntegerToString((long)signal_params.grid_stats.last_update_time);
  json += "}}";

  signal_params.grid_state_json = json;
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

void GridInitializePendingLevel(const SignalTypes direction,
                                GridOrderState &order_state,
                                const GridLevelPlan &level_plan,
                                const double point_size)
{
  double reference_price = order_state.anchor_price;
  if(reference_price <= 0.0)
    reference_price = GridCurrentPriceForDirection(direction, true);

  order_state.anchor_price     = reference_price;
  order_state.status           = GRID_ORDER_PENDING;
  order_state.last_action_time = TimeCurrent();

  double direction_mult = GridResolveDirectionMultiplier(direction);

  double stop_price = reference_price + direction_mult * level_plan.pending_order_points * point_size;
  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  if(direction == BULLISH && stop_price < entry_side_price)
    stop_price = entry_side_price;
  else if(direction == BEARISH && stop_price > entry_side_price)
    stop_price = entry_side_price;

  order_state.stop_loss_price    = stop_price;
  order_state.last_pending_price = stop_price;

  if(level_plan.take_profit_points > 0.0)
  {
    double expected_entry = stop_price;
    order_state.take_profit_price = expected_entry + direction_mult * level_plan.take_profit_points * point_size;
  }
  else
  {
    order_state.take_profit_price = 0.0;
  }

  if(level_plan.final_take_profit_points > 0.0)
    order_state.final_take_profit_price = order_state.anchor_price + direction_mult * level_plan.final_take_profit_points * point_size;
  else
    order_state.final_take_profit_price = 0.0;

  double adverse_reference = GridCurrentPriceForDirection(direction, false);
  order_state.next_level_price = adverse_reference - direction_mult * level_plan.distance_points * point_size;
  order_state.trailing_price   = 0.0;
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;
  order_state.entry_price        = 0.0;
  order_state.position_ticket    = 0;
  order_state.position_comment   = "";
}

void GridUpdatePendingLevel(const SignalTypes direction,
                            GridOrderState &order_state,
                            const GridLevelPlan &level_plan,
                            const double point_size)
{
  double direction_mult   = GridResolveDirectionMultiplier(direction);
  double reference_price  = order_state.anchor_price;
  if(reference_price <= 0.0)
    reference_price = GridCurrentPriceForDirection(direction, true);

  double stop_price = reference_price + direction_mult * level_plan.pending_order_points * point_size;
  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  if(direction == BULLISH && stop_price < entry_side_price)
    stop_price = entry_side_price;
  else if(direction == BEARISH && stop_price > entry_side_price)
    stop_price = entry_side_price;

  order_state.stop_loss_price    = stop_price;
  order_state.last_pending_price = stop_price;

  if(level_plan.take_profit_points > 0.0)
  {
    double expected_entry = stop_price;
    order_state.take_profit_price = expected_entry + direction_mult * level_plan.take_profit_points * point_size;
  }
  else
  {
    order_state.take_profit_price = 0.0;
  }

  if(level_plan.final_take_profit_points > 0.0)
    order_state.final_take_profit_price = order_state.anchor_price + direction_mult * level_plan.final_take_profit_points * point_size;
  else
    order_state.final_take_profit_price = 0.0;

  double adverse_reference = GridCurrentPriceForDirection(direction, false);
  order_state.next_level_price  = adverse_reference - direction_mult * level_plan.distance_points * point_size;
}

bool GridShouldActivatePendingLevel(const SignalTypes direction,
                                    const GridOrderState &order_state)
{
  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  if(direction == BULLISH)
    return (entry_side_price >= order_state.stop_loss_price && order_state.stop_loss_price > 0.0);
  return (entry_side_price <= order_state.stop_loss_price && order_state.stop_loss_price > 0.0);
}

bool GridExecuteLevelTrade(SignalParams &signal_params,
                           GridOrderState &order_state,
                           const GridLevelPlan &level_plan,
                           const double point_size,
                           const double normalized_volume)
{
  SignalTypes direction = signal_params.signal_type;
  double direction_mult = GridResolveDirectionMultiplier(direction);
  double expected_entry = order_state.stop_loss_price;
  string comment        = GridComposeLevelComment(signal_params, order_state);

  bool trade_sent = false;
  if(direction == BULLISH)
    trade_sent = g_position.Buy(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);
  else
    trade_sent = g_position.Sell(normalized_volume, _Symbol, 0.0, 0.0, 0.0, comment);

  if(!trade_sent)
  {
    if(Enable_Logs)
    {
      PrintFormat("Grid order execution failed | dir=%s | level=%d | retcode=%d",
                  EnumToString(direction),
                  order_state.level_index,
                  (int)g_position.ResultRetcode());
    }
    return false;
  }

  double fill_price = g_position.ResultPrice();
  if(fill_price <= 0.0)
    fill_price = expected_entry;

  order_state.status           = GRID_ORDER_ACTIVE;
  order_state.entry_price      = fill_price;
  if(order_state.anchor_price <= 0.0)
    order_state.anchor_price = fill_price;
  order_state.position_comment = comment;
  order_state.last_action_time = TimeCurrent();

  ulong deal_ticket = (ulong)g_position.ResultDeal();
  order_state.position_ticket = 0;
  if(deal_ticket > 0)
  {
    datetime history_start = TimeCurrent() - 86400;
    if(history_start < 0)
      history_start = 0;
    HistorySelect(history_start, TimeCurrent());
    if(HistoryDealSelect(deal_ticket))
    {
      ulong position_ticket = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
      if(position_ticket > 0)
        order_state.position_ticket = position_ticket;
    }
  }

  double adverse_reference = GridCurrentPriceForDirection(direction, false);

  order_state.take_profit_price = fill_price + direction_mult * level_plan.take_profit_points * point_size;
  order_state.stop_loss_price   = 0.0;
  order_state.last_pending_price = 0.0;
  if(level_plan.trailing_points > 0.0)
  {
    double base_trailing = adverse_reference - direction_mult * level_plan.trailing_points * point_size;
    order_state.trailing_price = base_trailing;
  }
  else
  {
    order_state.trailing_price = 0.0;
  }
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;

  if(level_plan.final_take_profit_points > 0.0)
    order_state.final_take_profit_price = order_state.anchor_price + direction_mult * level_plan.final_take_profit_points * point_size;
  else
    order_state.final_take_profit_price = 0.0;

  order_state.next_level_price = adverse_reference - direction_mult * level_plan.distance_points * point_size;

  if(signal_params.entry_price <= 0.0)
    signal_params.entry_price = fill_price;
  if(signal_params.entry_time == 0)
    signal_params.entry_time = TimeCurrent();
  if(signal_params.ticket_id == "")
    signal_params.ticket_id = comment;
  if(signal_params.grid_stats.activation_time == 0)
    signal_params.grid_stats.activation_time = TimeCurrent();

  GridLogEvent("LEVEL_ACTIVE", signal_params, order_state, level_plan);
  return true;
}

void GridFinalizeLevel(const SignalTypes direction,
                       GridOrderState &order_state,
                       const double point_size,
                       const double close_price_override)
{
  double close_price = close_price_override;
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  double entry_price = order_state.entry_price;
  if(point_size <= 0.0 || entry_price <= 0.0)
  {
    order_state.realized_points = 0.0;
    order_state.status          = GRID_ORDER_COMPLETED;
    order_state.last_action_time = TimeCurrent();
    order_state.position_ticket  = 0;
    order_state.position_comment = "";
    return;
  }

  double direction_mult = GridResolveDirectionMultiplier(direction);
  double point_delta    = (close_price - entry_price) / point_size * direction_mult;

  order_state.realized_points = point_delta;
  order_state.status          = GRID_ORDER_COMPLETED;
  order_state.last_action_time = TimeCurrent();
  order_state.position_ticket  = 0;
  order_state.position_comment = "";
  order_state.is_trailing_active = false;
  order_state.tp_reached         = false;
  order_state.final_take_profit_price = 0.0;
  order_state.next_level_price        = 0.0;
}

bool GridCloseBrokerPosition(GridOrderState &order_state,
                             const SignalTypes direction,
                             double &close_price)
{
  close_price = 0.0;

  if(order_state.position_ticket > 0)
  {
    if(!PositionSelectByTicket(order_state.position_ticket))
      order_state.position_ticket = 0;
  }

  if(order_state.position_ticket <= 0)
  {
    int total_positions = PositionsTotal();
    for(int i = 0; i < total_positions; i++)
    {
      if(PositionGetTicket(i) == 0)
        continue;

      if((int)PositionGetInteger(POSITION_MAGIC) != g_magic_number)
        continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
        continue;

      if(order_state.position_comment != "")
      {
        string comment = PositionGetString(POSITION_COMMENT);
        if(comment != order_state.position_comment)
          continue;
      }

      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(direction == BULLISH && pos_type != POSITION_TYPE_BUY)
        continue;
      if(direction == BEARISH && pos_type != POSITION_TYPE_SELL)
        continue;

      order_state.position_ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      break;
    }
  }

  if(order_state.position_ticket <= 0)
    return false;

  if(!PositionSelectByTicket(order_state.position_ticket))
    return false;

  if(!g_position.PositionClose(order_state.position_ticket))
  {
    if(Enable_Logs)
    {
      PrintFormat("PositionClose failed | ticket=%I64u | ret=%d",
                  order_state.position_ticket,
                  (int)g_position.ResultRetcode());
    }
    return false;
  }

  close_price = g_position.ResultPrice();
  if(close_price <= 0.0)
    close_price = GridCurrentPriceForDirection(direction, false);

  order_state.position_ticket  = 0;
  order_state.position_comment = "";
  return true;
}

void GridCloseAllLevels(SignalParams &signal_params,
                        const double point_size)
{
  SignalTypes direction = signal_params.signal_type;
  int levels_total = ArraySize(signal_params.grid_orders);

  for(int i = 0; i < levels_total; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    GridLevelPlan  plan  = signal_params.grid_plan.levels[i];

    if(state.status == GRID_ORDER_ACTIVE)
    {
      double close_price = 0.0;
      GridCloseBrokerPosition(state, direction, close_price);
      GridFinalizeLevel(direction, state, point_size, close_price);

      if(state.realized_points > 0.0)
        signal_params.grid_stats.total_positive_points += state.realized_points;
      else if(state.realized_points < 0.0)
        signal_params.grid_stats.total_negative_points += MathAbs(state.realized_points);

      signal_params.grid_stats.completed_levels++;
      GridLogEvent("LEVEL_CLOSE_ALL", signal_params, state, plan);
    }
    else if(state.status == GRID_ORDER_PENDING || state.status == GRID_ORDER_WAITING)
    {
      state.status = GRID_ORDER_COMPLETED;
      state.last_action_time = TimeCurrent();
      GridLogEvent("LEVEL_CANCELLED", signal_params, state, plan);
    }

    state.final_take_profit_price = 0.0;
    state.next_level_price        = 0.0;
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

  signal_params.grid_state_json = "";
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
  {
    GridComposeFrontendState(signal_params);
    return;
  }

  GridEnsureOrderArrayPrepared(signal_params);

  double point_size     = GridResolvePointSize();
  SignalTypes direction = signal_params.signal_type;
  double direction_mult = GridResolveDirectionMultiplier(direction);
  datetime now_time     = TimeCurrent();

  signal_params.grid_stats.last_update_time = now_time;

  bool request_close_all = false;

  int levels_total = ArraySize(signal_params.grid_plan.levels);
  for(int i = 0; i < levels_total; i++)
  {
    GridLevelPlan level_plan = signal_params.grid_plan.levels[i];
    GridOrderState order_state = signal_params.grid_orders[i];

    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, level_plan.lot_size);
    if(normalized_volume <= 0.0)
    {
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_WAITING)
    {
      if(i == 0)
      {
        if(GridGuardrailsAllowOrder(normalized_volume))
        {
          if(signal_params.grid_plan.base_anchor_price > 0.0)
            order_state.anchor_price = signal_params.grid_plan.base_anchor_price;
          GridInitializePendingLevel(direction, order_state, level_plan, point_size);
          GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
        }
        signal_params.grid_orders[i] = order_state;
        continue;
      }

      GridOrderState previous_state = signal_params.grid_orders[i - 1];
      bool previous_ready = (previous_state.status == GRID_ORDER_ACTIVE);
      if(previous_ready && previous_state.entry_price > 0.0)
      {
        double current_price = GridCurrentPriceForDirection(direction, false);
        double adverse_points = GridPointsBetween(direction,
                                                  previous_state.entry_price,
                                                  current_price,
                                                  point_size);
        if(adverse_points >= (level_plan.activation_points - 1e-6))
        {
          if(GridGuardrailsAllowOrder(normalized_volume))
          {
            GridLevelPlan previous_plan = signal_params.grid_plan.levels[i - 1];
            double base_anchor = previous_state.entry_price - direction_mult * previous_plan.distance_points * point_size;
            if(base_anchor <= 0.0)
              base_anchor = previous_state.anchor_price - direction_mult * previous_plan.distance_points * point_size;
            if(base_anchor > 0.0)
              order_state.anchor_price = base_anchor;
            GridInitializePendingLevel(direction, order_state, level_plan, point_size);
            GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
            previous_state.next_level_price        = 0.0;
            previous_state.take_profit_price       = 0.0;
            previous_state.final_take_profit_price = 0.0;
          }
        }
      }

      signal_params.grid_orders[i - 1] = previous_state;
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_PENDING)
    {
      GridUpdatePendingLevel(direction, order_state, level_plan, point_size);
      order_state.last_action_time = now_time;

      if(GridGuardrailsAllowOrder(normalized_volume) &&
         GridShouldActivatePendingLevel(direction, order_state))
      {
        if(GridExecuteLevelTrade(signal_params, order_state, level_plan, point_size, normalized_volume))
        {
          signal_params.signal_state = OPENED;
          GridLogEvent("LEVEL_FILLED", signal_params, order_state, level_plan);
        }
      }

      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_ACTIVE)
    {
      double close_price = GridCurrentPriceForDirection(direction, false);

      if(level_plan.final_take_profit_points > 0.0 && !order_state.tp_reached)
      {
        double final_price = order_state.anchor_price + direction_mult * level_plan.final_take_profit_points * point_size;
        order_state.final_take_profit_price = final_price;
        bool final_hit = false;
        if(direction == BULLISH)
        {
          if(final_price > order_state.entry_price)
            final_hit = (close_price >= final_price);
        }
        else
        {
          if(final_price < order_state.entry_price || order_state.entry_price <= 0.0)
            final_hit = (close_price <= final_price);
        }

        if(final_hit)
        {
          GridLogEvent("LEVEL_FINAL_TP", signal_params, order_state, level_plan);
          request_close_all = true;
        }
      }
      else
      {
        if(order_state.tp_reached)
          order_state.final_take_profit_price = 0.0;
      }

      if(level_plan.take_profit_points > 0.0 && !order_state.tp_reached)
      {
        double tp_price = order_state.entry_price + direction_mult * level_plan.take_profit_points * point_size;
        order_state.take_profit_price = tp_price;
        if((direction == BULLISH && close_price >= tp_price) ||
           (direction == BEARISH && close_price <= tp_price))
        {
          order_state.tp_reached = true;
          if(level_plan.trailing_points > 0.0)
            order_state.is_trailing_active = true;
          order_state.take_profit_price = 0.0;
        }
      }

      if(order_state.is_trailing_active && level_plan.trailing_points > 0.0)
      {
        double candidate_trailing = close_price - direction_mult * level_plan.trailing_points * point_size;

        if(order_state.trailing_price == 0.0)
          order_state.trailing_price = candidate_trailing;

        if(direction == BULLISH)
        {
          if(candidate_trailing > order_state.trailing_price)
            order_state.trailing_price = candidate_trailing;
          order_state.stop_loss_price = order_state.trailing_price;
          if(close_price <= order_state.trailing_price)
            request_close_all = true;
        }
        else
        {
          if(candidate_trailing < order_state.trailing_price || order_state.trailing_price == 0.0)
            order_state.trailing_price = candidate_trailing;
          order_state.stop_loss_price = order_state.trailing_price;
          if(close_price >= order_state.trailing_price)
            request_close_all = true;
        }
      }
      else
      {
        order_state.stop_loss_price = 0.0;
      }

      order_state.next_level_price = close_price - direction_mult * level_plan.distance_points * point_size;
      order_state.last_action_time = now_time;

      if(order_state.tp_reached)
        order_state.final_take_profit_price = 0.0;

      signal_params.grid_orders[i] = order_state;
      continue;
    }

    signal_params.grid_orders[i] = order_state;
  }

  if(request_close_all)
  {
    GridCloseAllLevels(signal_params, point_size);
    signal_params.signal_state = CLOSED;
  }

  if(point_size > 0.0 && signal_params.entry_price > 0.0)
  {
    double close_price = GridCurrentPriceForDirection(direction, false);
    double entry_price = signal_params.entry_price;
    double price_delta = (direction == BULLISH)
                         ? (close_price - entry_price)
                         : (entry_price - close_price);
    double points_delta = price_delta / point_size;
  if(points_delta > signal_params.grid_stats.max_favorable_points)
    signal_params.grid_stats.max_favorable_points = points_delta;
  if(points_delta < 0.0 && MathAbs(points_delta) > signal_params.grid_stats.max_adverse_points)
    signal_params.grid_stats.max_adverse_points = MathAbs(points_delta);
  }

  GridComposeFrontendState(signal_params);
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
