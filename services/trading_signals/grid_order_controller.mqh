#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

#include "../../microservices/trading_signals/grid_order_helpers.mqh"
#include "../../microservices/trading_signals/grid_order_math.mqh"
#include "../../microservices/trading_signals/grid_order_logging.mqh"
#include "../../microservices/trading_signals/grid_order_lifecycle.mqh"

// ── Public API ─────────────────────────────────────────────────────

void InitializeGridOrdersForSignal(SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return;

  signal_params.grid_stats = GridTelemetryStats();
  signal_params.grid_plan.resolved_base_distance_points = 0.0;
  signal_params.grid_plan.range_high_price = 0.0;
  signal_params.grid_plan.range_low_price  = 0.0;

  ArrayResize(signal_params.grid_orders, 0);
  int total_levels = ArraySize(signal_params.grid_plan.levels);
  if(total_levels <= 0)
    return;

  GridEnsureOrderState(signal_params, 0);
  GridOrderState initial_state = signal_params.grid_orders[0];
  GridResetOrderStateForWaiting(initial_state, signal_params.grid_plan.levels[0]);
  signal_params.grid_orders[0] = initial_state;
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_plan.initialized)
    return;

  double point_size     = GridResolvePointSize();
  SignalTypes direction = signal_params.signal_type;
  double direction_mult = GridResolveDirectionMultiplier(direction);
  datetime now_time     = TimeCurrent();

  signal_params.grid_stats.last_update_time = now_time;

  bool request_close_all = false;

  int levels_total = ArraySize(signal_params.grid_plan.levels);
  for(int i = 0; i < levels_total; i++)
  {
    if(i >= ArraySize(signal_params.grid_orders))
      continue;

    GridLevelPlan level_plan = signal_params.grid_plan.levels[i];
    GridOrderState order_state = signal_params.grid_orders[i];

    if(order_state.status == GRID_ORDER_INACTIVE)
    {
      signal_params.grid_orders[i] = order_state;
      continue;
    }

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
        string guardrail_reason = "";
        if(GridGuardrailsAllowOrder(normalized_volume, guardrail_reason))
        {
          if(signal_params.grid_plan.base_anchor_price > 0.0)
            order_state.anchor_price = signal_params.grid_plan.base_anchor_price;
          order_state.resolved_distance_points = level_plan.distance_points;
          GridInitializePendingLevel(signal_params,
                                     direction,
                                     order_state,
                                     point_size);
          level_plan = signal_params.grid_plan.levels[i];
          GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
        }
        else if(guardrail_reason != "")
        {
          GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, order_state, guardrail_reason);
          order_state.last_action_time = now_time;
        }
        signal_params.grid_orders[i] = order_state;
        continue;
      }

      if(i - 1 >= ArraySize(signal_params.grid_orders))
      {
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
          if(order_state.last_action_time != now_time)
            GridLogWaitingReady(signal_params, level_plan, adverse_points);
          string guardrail_reason = "";
          if(GridGuardrailsAllowOrder(normalized_volume, guardrail_reason))
          {
            double previous_distance_points = previous_state.resolved_distance_points;
            GridLevelPlan previous_plan = signal_params.grid_plan.levels[i - 1];
            if(previous_distance_points <= 0.0)
              previous_distance_points = previous_plan.distance_points;

            double base_anchor = previous_state.entry_price - direction_mult * previous_distance_points * point_size;
            if(previous_state.entry_price <= 0.0)
              base_anchor = previous_state.anchor_price - direction_mult * previous_distance_points * point_size;
            if(base_anchor <= 0.0)
              base_anchor = previous_state.anchor_price;

            order_state.anchor_price = base_anchor;
            order_state.resolved_distance_points = level_plan.distance_points;
            GridInitializePendingLevel(signal_params,
                                       direction,
                                       order_state,
                                       point_size);
            level_plan = signal_params.grid_plan.levels[i];
            GridLogEvent("LEVEL_PENDING", signal_params, order_state, level_plan);
            double previous_next_price             = previous_state.next_level_price;
            double new_next_price                  = level_plan.next_resolved_price;
            double change_threshold                = point_size;
            if(change_threshold <= 0.0)
              change_threshold = GridResolvePointSize();
            if(change_threshold <= 0.0)
              change_threshold = 1e-6;
            bool emit_next_update = false;
            if(new_next_price > 0.0)
            {
              if(previous_next_price <= 0.0 ||
                 MathAbs(new_next_price - previous_next_price) >= (change_threshold - 1e-9))
                emit_next_update = true;
            }
            else if(previous_next_price > 0.0)
            {
              emit_next_update = true;
            }
            previous_state.next_level_price        = new_next_price;
            previous_state.take_profit_price       = 0.0;
            previous_state.final_take_profit_price = 0.0;
            previous_plan.next_resolved_price      = level_plan.next_resolved_price;
            previous_plan.next_price_side          = level_plan.next_price_side;
            previous_plan.next_price_source        = level_plan.next_price_source;
            previous_plan.next_price_clamp_reason  = level_plan.next_price_clamp_reason;
            signal_params.grid_plan.levels[i - 1]  = previous_plan;
            if(emit_next_update)
            {
              GridLogEvent("LEVEL_NEXT_UPDATE", signal_params, previous_state, previous_plan);
            }
          }
          else if(guardrail_reason != "")
          {
            GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, order_state, guardrail_reason);
            order_state.last_action_time = now_time;
          }
          else
          {
            order_state.last_action_time = now_time;
          }
        }
      }

      signal_params.grid_orders[i - 1] = previous_state;
      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_PENDING)
    {

      level_plan = signal_params.grid_plan.levels[i];

      if(i > 0 && (i - 1) < ArraySize(signal_params.grid_orders))
      {
        GridOrderState previous_state = signal_params.grid_orders[i - 1];
        double previous_next_price = previous_state.next_level_price;
        double new_next_price = level_plan.next_resolved_price;
        double change_threshold = point_size;
        if(change_threshold <= 0.0)
          change_threshold = GridResolvePointSize();
        if(change_threshold <= 0.0)
          change_threshold = 1e-6;

        bool emit_next_update = false;
        if(new_next_price > 0.0)
        {
          if(previous_next_price <= 0.0 ||
             MathAbs(new_next_price - previous_next_price) >= (change_threshold - 1e-9))
            emit_next_update = true;
        }
        else if(previous_next_price > 0.0)
        {
          emit_next_update = true;
        }

        previous_state.next_level_price = new_next_price;
        if((i - 1) < ArraySize(signal_params.grid_plan.levels))
        {
          GridLevelPlan previous_plan = signal_params.grid_plan.levels[i - 1];
          previous_plan.next_resolved_price     = level_plan.next_resolved_price;
          previous_plan.next_price_side         = level_plan.next_price_side;
          previous_plan.next_price_source       = level_plan.next_price_source;
          previous_plan.next_price_clamp_reason = level_plan.next_price_clamp_reason;
          signal_params.grid_plan.levels[i - 1] = previous_plan;
        }
        signal_params.grid_orders[i - 1] = previous_state;

        if(emit_next_update)
        {
          GridLevelPlan logging_plan = GridLevelPlan();
          if((i - 1) < ArraySize(signal_params.grid_plan.levels))
            logging_plan = signal_params.grid_plan.levels[i - 1];
          GridLogEvent("LEVEL_NEXT_UPDATE", signal_params, previous_state, logging_plan);
        }
      }

      order_state.last_action_time = now_time;

      string guardrail_reason = "";
      bool guardrails_ok = GridGuardrailsAllowOrder(normalized_volume, guardrail_reason);

      if(guardrails_ok &&
         GridShouldActivatePendingLevel(direction, order_state, level_plan))
      {
        double execution_price = GridCurrentPriceForDirection(direction, true);
        if(GridApplyExecutionPriceAdjustment(signal_params,
                                             order_state,
                                             level_plan,
                                             direction,
                                             point_size,
                                             execution_price))
        {
          level_plan = signal_params.grid_plan.levels[i];
        }

        if(GridExecuteLevelTrade(signal_params, order_state, level_plan, point_size, normalized_volume))
        {
          signal_params.signal_state = OPENED;
          GridLevelPlan resolved_plan = level_plan;
          if(i < ArraySize(signal_params.grid_plan.levels))
            resolved_plan = signal_params.grid_plan.levels[i];
          GridLogEvent("LEVEL_FILLED", signal_params, order_state, resolved_plan);
        }
      }
      else if(!guardrails_ok && guardrail_reason != "")
      {
        GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, order_state, guardrail_reason);
      }

      signal_params.grid_orders[i] = order_state;
      continue;
    }

    if(order_state.status == GRID_ORDER_ACTIVE)
    {
      double close_price = GridCurrentPriceForDirection(direction, false);

      if(level_plan.final_take_profit_points > 0.0)
      {
        double final_reference_price = order_state.entry_price;
        if(final_reference_price <= 0.0)
          final_reference_price = order_state.last_pending_price;
        if(final_reference_price <= 0.0)
          final_reference_price = order_state.anchor_price;
        if(final_reference_price <= 0.0)
          final_reference_price = signal_params.grid_plan.base_anchor_price;

        double final_price = 0.0;
        if(final_reference_price > 0.0)
          final_price = final_reference_price + direction_mult * level_plan.final_take_profit_points * point_size;

        order_state.final_take_profit_price = final_price;

        bool final_hit = false;
        if(final_price > 0.0)
        {
          if(direction == BULLISH)
            final_hit = (close_price >= final_price);
          else if(direction == BEARISH)
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
        order_state.final_take_profit_price = 0.0;
      }

      double tp_price = 0.0;
      if(level_plan.take_profit_points > 0.0 && order_state.entry_price > 0.0)
        tp_price = order_state.entry_price + direction_mult * level_plan.take_profit_points * point_size;

      if(tp_price > 0.0 && !order_state.tp_reached)
      {
        order_state.take_profit_price = tp_price;
        bool tp_touch = ((direction == BULLISH) ? (close_price >= tp_price)
                                                : (close_price <= tp_price));
        if(tp_touch)
        {
          order_state.tp_reached = true;
          order_state.take_profit_price = 0.0;

          double trailing_offset_pts = 0.0;
          string trailing_basis = "";
          string trailing_reason_tokens = "";
          double trailing_price = GridResolveTrailingStopPrice(signal_params,
                                                               order_state,
                                                               level_plan,
                                                               direction,
                                                               point_size,
                                                               close_price,
                                                               trailing_offset_pts,
                                                               trailing_basis,
                                                               trailing_reason_tokens);
          if(trailing_price > 0.0)
          {
            order_state.is_trailing_active = true;
            order_state.trailing_price = trailing_price;
            order_state.stop_loss_price = trailing_price;
            order_state.trailing_points = trailing_offset_pts;
            GridAppendReason(trailing_reason_tokens, "tp_touch");
            string side_label = (direction == BULLISH) ? "BID" : "ASK";
            GridLogTrailingEvent("TRAILING_TP_START",
                                 signal_params,
                                 order_state,
                                 trailing_price,
                                 trailing_offset_pts,
                                 trailing_basis,
                                 side_label,
                                 trailing_reason_tokens);
          }
          else
          {
            order_state.is_trailing_active = false;
          }
        }
      }
      else if(tp_price > 0.0)
      {
        order_state.take_profit_price = order_state.tp_reached ? 0.0 : tp_price;
      }
      else
      {
        order_state.take_profit_price = 0.0;
      }

      if(order_state.is_trailing_active)
      {
        double trailing_offset_pts = 0.0;
        string trailing_basis = "";
        string trailing_reason_tokens = "";
        double candidate_trailing = GridResolveTrailingStopPrice(signal_params,
                                                                 order_state,
                                                                 level_plan,
                                                                 direction,
                                                                 point_size,
                                                                 close_price,
                                                                 trailing_offset_pts,
                                                                 trailing_basis,
                                                                 trailing_reason_tokens);
        if(candidate_trailing > 0.0)
        {
          double previous_trailing = order_state.trailing_price;
          double tolerance = point_size;
          if(tolerance <= 0.0)
            tolerance = 1e-6;
          bool price_moved = false;
          if(previous_trailing <= 0.0)
            price_moved = true;
          else if(direction == BULLISH && candidate_trailing > previous_trailing + tolerance)
            price_moved = true;
          else if(direction == BEARISH && candidate_trailing < previous_trailing - tolerance)
            price_moved = true;

          order_state.trailing_points = trailing_offset_pts;

          if(price_moved)
          {
            order_state.trailing_price = candidate_trailing;
            string update_reason = trailing_reason_tokens;
            GridAppendReason(update_reason, "follow_move");
            string side_label = (direction == BULLISH) ? "BID" : "ASK";
            GridLogTrailingEvent("TRAILING_TP_UPDATE",
                                 signal_params,
                                 order_state,
                                 candidate_trailing,
                                 trailing_offset_pts,
                                 trailing_basis,
                                 side_label,
                                 update_reason);
          }

          if(order_state.trailing_price <= 0.0)
            order_state.trailing_price = candidate_trailing;

          order_state.stop_loss_price = order_state.trailing_price;

          bool trailing_hit = false;
          string hit_side = (direction == BULLISH) ? "BID" : "ASK";
          if(direction == BULLISH && order_state.trailing_price > 0.0 && close_price <= order_state.trailing_price)
            trailing_hit = true;
          else if(direction == BEARISH && order_state.trailing_price > 0.0 && close_price >= order_state.trailing_price)
            trailing_hit = true;

          if(trailing_hit)
          {
            string hit_reason = trailing_reason_tokens;
            GridAppendReason(hit_reason, "price_cross");
            GridLogTrailingEvent("TRAILING_TP_HIT",
                                 signal_params,
                                 order_state,
                                 order_state.trailing_price,
                                 trailing_offset_pts,
                                 trailing_basis,
                                 hit_side,
                                 hit_reason);
            order_state.is_trailing_active = false;
            request_close_all = true;
          }
        }
        else
        {
          order_state.is_trailing_active = false;
          order_state.stop_loss_price = 0.0;
        }
      }
      else
      {
        order_state.stop_loss_price = 0.0;
      }

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
