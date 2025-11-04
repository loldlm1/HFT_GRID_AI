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
extern double                   g_bid;
extern double                   g_ask;

bool FetchAtrGridContext(const SignalTypes direction,
                         const ENUM_TIMEFRAMES tf,
                         double &distance_points,
                         double &anchor_price)
{
  int total_atr_handles = ArraySize(ExtATRIndicatorsHandle);
  if(total_atr_handles <= 0)
    return false;

  for(int i = 0; i < total_atr_handles; i++)
  {
    if(ExtATRIndicatorsHandle[i].indicator_timeframe != tf)
      continue;

    int buffer_index = (direction == BULLISH) ? 1 : 0;
    double atr_reference[];
    if(CopyBuffer(ExtATRIndicatorsHandle[i].indicator_handle,
                  buffer_index,
                  1,
                  1,
                  atr_reference) <= 0)
      return false;

    anchor_price = atr_reference[0];
    double current_price = (direction == BULLISH) ? g_ask : g_bid;
    double point_size    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(point_size <= 0.0 || current_price <= 0.0 || anchor_price <= 0.0)
      return false;

    distance_points = MathAbs(current_price - anchor_price) / point_size;
    return (distance_points > 0.0);
  }

  return false;
}

bool CalculateBaseGridContext(const SignalTypes direction,
                              const ENUM_TIMEFRAMES tf,
                              double &distance_points,
                              double &anchor_price)
{
  distance_points = 0.0;
  anchor_price    = 0.0;

  if(Grid_Base_Strategy_Type == ATR_RANGE)
  {
    if(!FetchAtrGridContext(direction, tf, distance_points, anchor_price))
    {
      Print("Failed to fetch ATR distance, falling back to direct points input.");
      distance_points = Grid_ATR_Points_Setup;
    }
    else
    {
      distance_points = distance_points * MathMax(Grid_ATR_Points_Setup, 1.0);
    }
  }
  else
  {
    distance_points = Grid_ATR_Points_Setup;
  }

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  if(anchor_price <= 0.0)
  {
    double current_price = (direction == BULLISH) ? g_ask : g_bid;
    double direction_mult = (direction == BULLISH) ? 1.0 : -1.0;
    anchor_price = current_price - direction_mult * distance_points * point_size;
  }

  distance_points = EnforceBrokerDistance(g_symbol_constraints, distance_points);
  return (distance_points > 0.0);
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

  double base_distance_points = 0.0;
  double base_anchor_price    = 0.0;

  if(!CalculateBaseGridContext(signal_params.signal_type,
                               Strategy_Timeframe,
                               base_distance_points,
                               base_anchor_price))
  {
    Print("Grid plan aborted: base distance not available.");
    return false;
  }

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
  signal_params.grid_plan.base_anchor_price    = base_anchor_price;
  signal_params.grid_plan.base_lot_size        = base_lot;
  signal_params.grid_plan.direction            = signal_params.signal_type;
  signal_params.grid_plan.resolved_base_distance_points = 0.0;
  signal_params.grid_plan.range_high_price     = 0.0;
  signal_params.grid_plan.range_low_price      = 0.0;

  for(int level_index = 0; level_index < GRID_MAX_LEVELS; level_index++)
  {
    GridLevelPlan level_plan;
    level_plan.level_index     = level_index;
    level_plan.distance_points = base_distance_points * MathPow(exponential_multiplier, level_index);
    level_plan.resolved_distance_points = 0.0;
    double scaled_lot          = base_lot * MathPow(lot_multiplier, level_index);
    level_plan.lot_size        = NormalizeVolumeForSymbol(_Symbol, scaled_lot);
    level_plan.grid_range_percent = -1.0;

    double entry_percent = (level_index == 0) ? initial_stop_percent : deep_stop_percent;
    double entry_offset  = level_plan.distance_points * (entry_percent / 100.0);
    entry_offset         = (entry_offset > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, entry_offset) : 0.0;
    double pending_points = level_plan.distance_points + entry_offset;

    double activation_distance = level_plan.distance_points;
    activation_distance        = (activation_distance > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, activation_distance) : 0.0;

    double tp_activation = level_plan.distance_points * (tp_percent / 100.0);
    tp_activation        = (tp_activation > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, tp_activation) : 0.0;

    double final_tp_points = level_plan.distance_points * (Grid_Final_TP_Percent / 100.0);
    if(final_tp_points < 0.0)
      final_tp_points = 0.0;

    double trailing_distance = 0.0;
    if(trailing_percent > 0.0 && tp_activation > 0.0)
    {
      trailing_distance = tp_activation * (trailing_percent / 100.0);
      trailing_distance = (trailing_distance > 0.0) ? EnforceBrokerDistance(g_symbol_constraints, trailing_distance) : 0.0;
    }

    level_plan.pending_order_points = pending_points;
    level_plan.activation_points    = activation_distance;
    level_plan.take_profit_points   = tp_activation;
    level_plan.final_take_profit_points = final_tp_points;
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
