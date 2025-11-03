//+------------------------------------------------------------------+
//|                                       trading_signals/grid_planner.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
#define _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_

#include "../../microservices/utils/array_functions.mqh"
#include "../../microservices/utils/broker_constraints_helper.mqh"
#include "../../microservices/utils/money_functions.mqh"

const int GRID_MAX_LEVELS = 6;

extern SymbolTradingConstraints g_symbol_constraints;
extern IndicatorsHandleInfo     ExtATRIndicatorsHandle[];

double CalculateBaseGridDistancePoints()
{
  double distance_points = 0.0;

  if(Grid_Base_Strategy_Type == ATR_RANGE)
  {
    double atr_points = 0.0;
    if(!FetchAtrDistancePoints(Strategy_Timeframe, atr_points))
    {
      Print("Failed to fetch ATR distance, falling back to direct points input.");
      distance_points = Grid_ATR_Points_Setup;
    }
    else
    {
      distance_points = atr_points * Grid_ATR_Points_Setup;
    }
  }
  else
  {
    distance_points = Grid_ATR_Points_Setup;
  }

  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return distance_points;
}

bool FetchAtrDistancePoints(ENUM_TIMEFRAMES tf, double &distance_points)
{
  int total_atr_handles = ArraySize(ExtATRIndicatorsHandle);
  if(total_atr_handles <= 0)
    return false;

  for(int i = 0; i < total_atr_handles; i++)
  {
    if(ExtATRIndicatorsHandle[i].indicator_timeframe != tf)
      continue;

    double atr_buffer[];
    if(CopyBuffer(ExtATRIndicatorsHandle[i].indicator_handle, 2, 0, 1, atr_buffer) <= 0)
      return false;

    double atr_price  = atr_buffer[0];
    double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(point_size <= 0.0)
      return false;

    distance_points = atr_price / point_size;
    return distance_points > 0.0;
  }

  return false;
}

double ResolveBaseGridLot(const double base_distance_points)
{
  double base_lot = Grid_Lot_Strategy_Size;

  if(Grid_Lot_Type == GRID_LOT_SIZE)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double reference_points = base_distance_points;
  if(Grid_TP_Percent > 0.0)
    reference_points = base_distance_points * (Grid_TP_Percent / 100.0);
  if(reference_points <= 0.0)
    reference_points = base_distance_points;

  double target_amount = 0.0;
  if(Grid_Lot_Type == GRID_LOT_PERCENTAGE_BASED)
  {
    double base_balance = Account_Size;
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(account_balance > 0.0)
      base_balance = account_balance;
    target_amount = base_balance * (Grid_Lot_Strategy_Size / 100.0);
  }
  else if(Grid_Lot_Type == GRID_LOT_CURRENCY_BASED)
  {
    target_amount = Grid_Lot_Strategy_Size;
  }

  target_amount = MathAbs(target_amount);

  if(target_amount <= 0.0 || reference_points <= 0.0)
    return NormalizeVolumeForSymbol(_Symbol, base_lot);

  double resolved_lot = ConvertAmountToLots(_Symbol, target_amount, reference_points);
  if(resolved_lot <= 0.0)
    resolved_lot = base_lot;
  return NormalizeVolumeForSymbol(_Symbol, resolved_lot);
}

bool BuildGridPlanForSignal(SignalParams &signal_params)
{
  ArrayResize(signal_params.grid_plan.levels, 0);
  signal_params.grid_plan.initialized = false;

  double base_distance_points = CalculateBaseGridDistancePoints();
  if(base_distance_points <= 0.0)
  {
    Print("Grid plan aborted: base distance not available.");
    return false;
  }

  double exponential_multiplier = MathMax(Grid_Exponential_Multiplier, 1.0);
  double lot_multiplier         = MathMax(Grid_Multiplier, 1.0);
  double tp_percent             = MathMax(Grid_TP_Percent, 0.0);
  double trailing_percent       = MathMax(Grid_Trailing_TP_Percent, 0.0);
  double initial_stop_percent   = MathMax(Grid_Initial_Stops_Percent, 0.0);
  double deep_stop_percent      = MathMax(Grid_Positions_Stops_Percent, 0.0);

  double base_lot = signal_params.lot_size;
  if(base_lot <= 0.0)
    base_lot = ResolveBaseGridLot(base_distance_points);
  if(base_lot <= 0.0)
  {
    double min_vol = g_symbol_constraints.min_volume;
    if(min_vol <= 0.0)
      min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(min_vol <= 0.0)
      min_vol = 0.01;
    base_lot = min_vol;
  }

  signal_params.grid_plan.base_distance_points = base_distance_points;
  signal_params.grid_plan.base_lot_size        = base_lot;
  signal_params.grid_plan.direction            = signal_params.signal_type;

  for(int level_index = 0; level_index < GRID_MAX_LEVELS; level_index++)
  {
    GridLevelPlan level_plan;
    level_plan.level_index     = level_index;
    level_plan.distance_points = base_distance_points * MathPow(exponential_multiplier, level_index);
    double scaled_lot          = base_lot * MathPow(lot_multiplier, level_index);
    level_plan.lot_size        = NormalizeVolumeForSymbol(_Symbol, scaled_lot);

    double stop_percent  = (level_index == 0) ? initial_stop_percent : deep_stop_percent;
    double stop_distance = level_plan.distance_points * (stop_percent / 100.0);
    stop_distance        = (stop_distance > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, stop_distance) : 0.0;

    double pending_distance = (level_index == 0)
                              ? level_plan.distance_points * (initial_stop_percent / 100.0)
                              : level_plan.distance_points * (deep_stop_percent / 100.0);
    pending_distance        = (pending_distance > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, pending_distance) : 0.0;

    double next_distance = level_plan.distance_points;
    if(level_index < GRID_MAX_LEVELS - 1)
      next_distance = base_distance_points * MathPow(exponential_multiplier, level_index + 1);

    double tp_activation = next_distance * (tp_percent / 100.0);
    tp_activation        = (tp_activation > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, tp_activation) : 0.0;

    double trailing_distance = 0.0;
    if(trailing_percent > 0.0 && tp_activation > 0.0)
    {
      trailing_distance = tp_activation * (trailing_percent / 100.0);
      trailing_distance = (trailing_distance > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, trailing_distance) : 0.0;
    }

    level_plan.stop_loss_points     = stop_distance;
    level_plan.pending_order_points = pending_distance;
    level_plan.take_profit_points   = tp_activation;
    level_plan.trailing_points      = trailing_distance;

    AddElementToArray(signal_params.grid_plan.levels, level_plan);
  }

  signal_params.grid_plan.initialized = true;

  if(Enable_Logs)
  {
    PrintFormat("Grid plan ready | direction=%s | base_distance=%.2f pts | levels=%d",
                EnumToString(signal_params.grid_plan.direction),
                signal_params.grid_plan.base_distance_points,
                ArraySize(signal_params.grid_plan.levels));
  }

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_GRID_PLANNER_MQH_
