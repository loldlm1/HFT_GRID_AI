//+------------------------------------------------------------------+
//|                        microservices/trading_signals/... math    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
// grid_order_helpers is provided earlier in the trading_signals cascade

ExecutionLotTypes ResolveEffectiveGridLotType(const ExecutionLotTypes lot_type)
{
  if(lot_type == EXECUTION_LOT_ACCOUNT_PERCENTAGE ||
     lot_type == EXECUTION_LOT_TARGET_CURRENCY ||
     lot_type == EXECUTION_LOT_FIXED_SIZE)
  {
    return lot_type;
  }

  return EXECUTION_LOT_FIXED_SIZE;
}

bool GridIsTargetProfitLotType(const ExecutionLotTypes lot_type)
{
  ExecutionLotTypes effective_lot_type = ResolveEffectiveGridLotType(lot_type);
  return (effective_lot_type == EXECUTION_LOT_ACCOUNT_PERCENTAGE ||
          effective_lot_type == EXECUTION_LOT_TARGET_CURRENCY);
}

bool GridUsesTargetProfitLotMode()
{
  return GridIsTargetProfitLotType(ResolveEffectiveGridLotType(Lot_Type));
}

bool GridShouldApplyLotMultiplier(const ExecutionLotTypes lot_type)
{
  ExecutionLotTypes effective_lot_type = ResolveEffectiveGridLotType(lot_type);
  return (effective_lot_type == EXECUTION_LOT_FIXED_SIZE);
}

double ResolveTargetProfitFactorFromPercent(const double tp_percent)
{
  if(!MathIsValidNumber(tp_percent) || tp_percent <= 0.0)
    return 1.0;

  return tp_percent / 100.0;
}

double ResolveTargetProfitAmountFromInputs(const ExecutionLotTypes lot_type,
                                           const double lot_strategy_size,
                                           const double tp_percent,
                                           const double account_balance,
                                           const double account_size_fallback)
{
  ExecutionLotTypes effective_lot_type = ResolveEffectiveGridLotType(lot_type);
  double factor = ResolveTargetProfitFactorFromPercent(tp_percent);
  double strategy_size = MathAbs(lot_strategy_size);

  if(effective_lot_type == EXECUTION_LOT_TARGET_CURRENCY)
    return strategy_size * factor;

  if(effective_lot_type == EXECUTION_LOT_ACCOUNT_PERCENTAGE)
  {
    double account_reference = MathAbs(account_balance);
    if(account_reference <= 0.0)
      account_reference = MathAbs(account_size_fallback);
    if(account_reference <= 0.0)
      return 0.0;

    double base_amount = account_reference * (strategy_size / 100.0);
    return base_amount * factor;
  }

  return strategy_size;
}

double ResolveGridRuntimeTargetProfitAmount(const ExecutionLotTypes lot_type)
{
  double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
  return ResolveTargetProfitAmountFromInputs(lot_type,
                                             Lot_Strategy_Size,
                                             TP_Percent,
                                             account_balance,
                                             Account_Size);
}

double ResolveSymbolPointValuePerLot(const string symbol)
{
  double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
  double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
  double point_size = SymbolInfoDouble(symbol, SYMBOL_POINT);

  if(tick_value > 0.0 && tick_size > 0.0 && point_size > 0.0)
  {
    double point_value = tick_value * (point_size / tick_size);
    if(MathIsValidNumber(point_value) && point_value > 0.0)
      return point_value;
  }

  if(point_size <= 0.0)
    return 0.0;

  double bid_price = SymbolInfoDouble(symbol, SYMBOL_BID);
  double ask_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
  double entry_price = (bid_price > 0.0) ? bid_price : ask_price;
  if(entry_price <= 0.0)
    return 0.0;

  double valid_volume = CommonVolume(symbol);
  if(valid_volume <= 0.0)
    valid_volume = 1.0;

  double close_price = entry_price + point_size;
  double point_profit = 0.0;
  if(!OrderCalcProfit(ORDER_TYPE_BUY,
                      symbol,
                      valid_volume,
                      entry_price,
                      close_price,
                      point_profit))
  {
    return 0.0;
  }

  double point_value_fallback = MathAbs(point_profit) / valid_volume;
  if(!MathIsValidNumber(point_value_fallback) || point_value_fallback <= 0.0)
    return 0.0;

  return point_value_fallback;
}

double ResolveProjectedGridOrderProfitAtPrice(const SignalTypes direction,
                                              const double entry_price,
                                              const double close_price,
                                              const double lot_size)
{
  if(entry_price <= 0.0 || close_price <= 0.0 || lot_size <= 0.0)
    return 0.0;

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    return 0.0;

  double signed_points = 0.0;
  if(direction == BULLISH)
    signed_points = (close_price - entry_price) / point_size;
  else if(direction == BEARISH)
    signed_points = (entry_price - close_price) / point_size;
  else
    return 0.0;

  if(!MathIsValidNumber(signed_points))
    return 0.0;

  double point_value = ResolveSymbolPointValuePerLot(_Symbol);
  if(point_value <= 0.0)
    return 0.0;

  double projected_profit = lot_size * point_value * signed_points;
  if(!MathIsValidNumber(projected_profit))
    return 0.0;

  return projected_profit;
}

double ResolveProjectedBasketProfitAtPrice(const SignalParams &signal_params,
                                           const double close_price,
                                           const int skip_level_index = -1)
{
  double basket_profit = 0.0;
  int total_levels = ArraySize(signal_params.grid_orders);

  for(int idx = 0; idx < total_levels; idx++)
  {
    if(idx == skip_level_index)
      continue;

    GridOrderState state = signal_params.grid_orders[idx];
    if(!state.opens_position)
      continue;
    if(state.status != EXECUTION_LEG_ACTIVE)
      continue;
    if(state.lot_size <= 0.0)
      continue;

    double entry_price = state.entry_price;
    if(entry_price <= 0.0)
      entry_price = state.entry_reference_price;
    if(entry_price <= 0.0)
      continue;

    basket_profit += ResolveProjectedGridOrderProfitAtPrice(signal_params.signal_type,
                                                            entry_price,
                                                            close_price,
                                                            state.lot_size);
  }

  return basket_profit;
}

bool ResolveRequiredLotForTarget(const double target_profit_amount,
                                 const double projected_existing_profit,
                                 const double projected_profit_per_lot,
                                 double &required_lot_out);

bool ResolveRequiredLotForTargetAtPrice(const SignalParams &signal_params,
                                        const int candidate_level_index,
                                        const double candidate_entry_price,
                                        const double close_price,
                                        const double target_profit_amount,
                                        double &required_lot_out)
{
  required_lot_out = 0.0;

  if(candidate_entry_price <= 0.0 || close_price <= 0.0 || target_profit_amount <= 0.0)
    return false;

  double projected_existing_profit = ResolveProjectedBasketProfitAtPrice(signal_params,
                                                                         close_price,
                                                                         candidate_level_index);
  double projected_profit_per_lot = ResolveProjectedGridOrderProfitAtPrice(signal_params.signal_type,
                                                                            candidate_entry_price,
                                                                            close_price,
                                                                            1.0);
  if(projected_profit_per_lot <= 0.0)
    return false;

  if(!ResolveRequiredLotForTarget(target_profit_amount,
                                  projected_existing_profit,
                                  projected_profit_per_lot,
                                  required_lot_out))
  {
    return false;
  }

  return true;
}

bool ResolveRequiredLotForTarget(const double target_profit_amount,
                                 const double projected_existing_profit,
                                 const double projected_profit_per_lot,
                                 double &required_lot_out)
{
  required_lot_out = 0.0;

  if(!MathIsValidNumber(target_profit_amount) || target_profit_amount <= 0.0)
    return false;
  if(!MathIsValidNumber(projected_existing_profit))
    return false;
  if(!MathIsValidNumber(projected_profit_per_lot) || projected_profit_per_lot <= 0.0)
    return false;

  double numerator = target_profit_amount - projected_existing_profit;
  if(!MathIsValidNumber(numerator))
    return false;

  required_lot_out = numerator / projected_profit_per_lot;
  return MathIsValidNumber(required_lot_out);
}

double NormalizeVolumeUpForSymbol(const string symbol, const double volume)
{
  if(volume <= 0.0)
    return 0.0;

  double min_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
  double max_vol  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
  double step_vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

  double normalized = volume;
  if(min_vol > 0.0 && normalized < min_vol)
    normalized = min_vol;

  if(step_vol > 0.0)
  {
    double steps = MathCeil((normalized - 1e-12) / step_vol);
    normalized = steps * step_vol;

    int vol_digits = 0;
    if(step_vol < 1.0)
    {
      vol_digits = (int)MathRound(-MathLog10(step_vol));
      if(vol_digits < 0)
        vol_digits = 0;
    }
    normalized = NormalizeDouble(normalized, vol_digits);
  }

  if(max_vol > 0.0 && normalized > max_vol)
    normalized = max_vol;

  return normalized;
}

bool NormalizeTargetModeRequiredLot(const string symbol,
                                    const double required_lot,
                                    double &normalized_lot,
                                    bool &infeasible)
{
  normalized_lot = 0.0;
  infeasible = false;

  if(required_lot <= 0.0)
    return true;

  double max_vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
  if(max_vol > 0.0 && required_lot > max_vol + 1e-9)
  {
    infeasible = true;
    return false;
  }

  normalized_lot = NormalizeVolumeUpForSymbol(symbol, required_lot);
  if(normalized_lot <= 0.0)
  {
    infeasible = true;
    return false;
  }

  if(max_vol > 0.0 && normalized_lot > max_vol + 1e-9)
  {
    infeasible = true;
    return false;
  }

  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
