#ifndef _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_

#include "../../microservices/trading_signals/grid_order_helpers.mqh"
#include "../../microservices/trading_signals/grid_order_math.mqh"
#include "../../microservices/trading_signals/grid_order_logging.mqh"
#include "../../microservices/trading_signals/grid_order_lifecycle.mqh"

void InitializeGridOrdersForSignal(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return;

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    state.status = (i == 0) ? GRID_ORDER_WAITING : GRID_ORDER_INACTIVE;
    state.entry_price = 0.0;
    state.take_profit_price = 0.0;
    state.final_take_profit_price = 0.0;
    state.trailing_price = 0.0;
    state.tp_reference_points = 0.0;
    state.position_ticket = 0;
    state.position_comment = "";
    state.is_trailing_active = false;
    state.tp_reached = false;
    state.last_action_time = 0;
    signal_params.grid_orders[i] = state;
  }
}

void UpdateGridLifecycle(SignalParams &signal_params)
{
  if(!signal_params.grid_initialized)
    return;

  double point_size = GridResolvePointSize();
  SignalTypes direction = signal_params.signal_type;
  int total_levels = ArraySize(signal_params.grid_orders);

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState state = signal_params.grid_orders[i];
    double normalized_volume = NormalizeVolumeForSymbol(_Symbol, state.lot_size);

    switch(state.status)
    {
      case GRID_ORDER_WAITING:
      {
        bool previous_ready = (i == 0);
        if(i > 0)
        {
          GridOrderState prev = signal_params.grid_orders[i - 1];
          previous_ready = (prev.status == GRID_ORDER_ACTIVE ||
                            prev.status == GRID_ORDER_COMPLETED);
        }

        if(!previous_ready)
          break;

        string guardrail_reason = "";
        if(GridGuardrailsAllowOrder(normalized_volume, guardrail_reason))
        {
          GridInitializePendingLevel(signal_params, direction, state, point_size);
          GridLogEvent("LEVEL_PENDING", signal_params, state);
        }
        else if(guardrail_reason != "")
        {
          GridLogGuardrailBlock("ACTIVATION_BLOCKED", signal_params, state, guardrail_reason);
        }
        break;
      }

      case GRID_ORDER_STOP_TRAILING_ACTIVE:
      {
        double previous_stop = state.next_level_price;
        if(GridRefreshStopTriggerFromAtr(signal_params, state, point_size))
        {
          if(previous_stop > 0.0 &&
             MathAbs(state.next_level_price - previous_stop) >= point_size)
          {
            GridLogEvent("LEVEL_PENDING_UPDATE", signal_params, state);
          }
        }

        if(GridShouldActivatePendingLevel(signal_params, state, direction, point_size))
        {
          if(GridExecuteLevelTrade(signal_params, state, point_size, normalized_volume))
          {
            GridLogEvent("LEVEL_FILLED", signal_params, state);
            GridScheduleNextLevel(signal_params, i + 1);
          }
        }
        break;
      }

      case GRID_ORDER_ACTIVE:
      {
        double current_price = GridCurrentPriceForDirection(direction, false);
        bool close_order = false;

        if(state.take_profit_price > 0.0)
        {
          if(direction == BULLISH && current_price >= state.take_profit_price)
            close_order = true;
          if(direction == BEARISH && current_price <= state.take_profit_price)
            close_order = true;
        }

        if(close_order)
        {
          GridFinalizeLevel(direction, state, point_size, current_price);
          GridLogEvent("LEVEL_COMPLETED", signal_params, state);
        }
        break;
      }

      default:
        break;
    }

    signal_params.grid_orders[i] = state;
  }

  if(IsGridSignalComplete(signal_params))
    signal_params.signal_state = CLOSED;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_ORDER_CONTROLLER_MQH_
