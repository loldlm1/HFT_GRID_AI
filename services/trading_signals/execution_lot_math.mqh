//+------------------------------------------------------------------+
//|                                      execution_lot_math          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_

int ExecutionVolumeDigits(const double volume_step)
{
  if(volume_step <= 0.0 || volume_step >= 1.0)
    return 0;
  int digits = (int)MathCeil(-MathLog10(volume_step) - 1e-9);
  if(digits < 0)
    digits = 0;
  if(digits > 8)
    digits = 8;
  return digits;
}

double NormalizeExecutionVolumeDown(const string symbol,
                                    const double requested_volume)
{
  if(requested_volume <= 0.0)
    return 0.0;

  double min_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
  double max_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
  double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
  if(min_volume <= 0.0 || max_volume <= 0.0 || volume_step <= 0.0)
    return 0.0;

  double capped = MathMin(requested_volume, max_volume);
  double steps = MathFloor((capped + 1e-12) / volume_step);
  double normalized = NormalizeDouble(steps * volume_step,
                                      ExecutionVolumeDigits(volume_step));
  if(normalized + 1e-12 < min_volume)
    return 0.0;
  return normalized;
}

bool ResolveExecutionLossPerLot(const SignalTypes direction,
                                const double entry_price,
                                const double stop_loss_price,
                                double &loss_per_lot_out)
{
  loss_per_lot_out = 0.0;
  ENUM_ORDER_TYPE order_type = direction == BULLISH
                               ? ORDER_TYPE_BUY
                               : ORDER_TYPE_SELL;
  double profit = 0.0;
  if(!OrderCalcProfit(order_type,
                      _Symbol,
                      1.0,
                      entry_price,
                      stop_loss_price,
                      profit))
    return false;

  loss_per_lot_out = MathAbs(profit);
  return MathIsValidNumber(loss_per_lot_out) && loss_per_lot_out > 0.0;
}

bool ResolveExecutionVolumePlan(const SignalTypes direction,
                                const double entry_price,
                                const double stop_loss_price,
                                double &requested_volume_out,
                                double &normalized_volume_out,
                                double &risk_target_amount_out,
                                double &expected_stop_loss_out,
                                string &reason_out)
{
  requested_volume_out = 0.0;
  normalized_volume_out = 0.0;
  risk_target_amount_out = 0.0;
  expected_stop_loss_out = 0.0;
  reason_out = "";

  bool geometry_valid = false;
  if(direction == BULLISH)
    geometry_valid = stop_loss_price > 0.0 && stop_loss_price < entry_price;
  else if(direction == BEARISH)
    geometry_valid = stop_loss_price > entry_price;
  if(entry_price <= 0.0 || !geometry_valid)
  {
    reason_out = "INVALID_ENTRY_STOP_GEOMETRY";
    return false;
  }

  double configured_size = Lot_Strategy_Size;
  if(configured_size <= 0.0 || !MathIsValidNumber(configured_size))
  {
    reason_out = "LOT_STRATEGY_SIZE_INVALID";
    return false;
  }

  if(Lot_Type == EXECUTION_LOT_FIXED_SIZE)
  {
    requested_volume_out = configured_size;
  }
  else if(Lot_Type == EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT)
  {
    if(configured_size > 100.0)
    {
      reason_out = "ACCOUNT_BALANCE_PERCENT_OUT_OF_RANGE";
      return false;
    }

    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double loss_per_lot = 0.0;
    if(account_balance <= 0.0 ||
       !MathIsValidNumber(account_balance) ||
       !ResolveExecutionLossPerLot(direction,
                                   entry_price,
                                   stop_loss_price,
                                   loss_per_lot))
    {
      reason_out = "RISK_BUDGET_OR_ORDER_CALC_PROFIT_INVALID";
      return false;
    }

    risk_target_amount_out = account_balance * configured_size / 100.0;
    if(risk_target_amount_out <= 0.0)
    {
      reason_out = "RISK_BUDGET_INVALID";
      return false;
    }
    requested_volume_out = risk_target_amount_out / loss_per_lot;
  }
  else
  {
    reason_out = "LOT_TYPE_INVALID";
    return false;
  }

  normalized_volume_out = NormalizeExecutionVolumeDown(_Symbol,
                                                       requested_volume_out);
  if(normalized_volume_out <= 0.0)
  {
    reason_out = "NORMALIZED_VOLUME_BELOW_BROKER_MINIMUM_OR_INVALID";
    return false;
  }

  ENUM_ORDER_TYPE order_type = direction == BULLISH
                               ? ORDER_TYPE_BUY
                               : ORDER_TYPE_SELL;
  double stop_profit = 0.0;
  if(!OrderCalcProfit(order_type,
                      _Symbol,
                      normalized_volume_out,
                      entry_price,
                      stop_loss_price,
                      stop_profit))
  {
    reason_out = "NORMALIZED_ORDER_CALC_PROFIT_FAILED";
    return false;
  }

  expected_stop_loss_out = MathAbs(stop_profit);
  if(Lot_Type == EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT &&
     expected_stop_loss_out > risk_target_amount_out * (1.0 + 1e-9))
  {
    reason_out = "NORMALIZED_VOLUME_EXCEEDS_RISK_BUDGET";
    return false;
  }
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
