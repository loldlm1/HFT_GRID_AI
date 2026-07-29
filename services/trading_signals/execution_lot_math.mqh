//+------------------------------------------------------------------+
//|                                      execution_lot_math.mqh      |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_

double ResolveExecutionOneRTarget(const SignalTypes direction,
                                  const double entry_price,
                                  const double stop_loss_price)
{
  if(entry_price <= 0.0 || stop_loss_price <= 0.0)
    return 0.0;

  double risk_distance = MathAbs(entry_price - stop_loss_price);
  if(risk_distance <= 0.0)
    return 0.0;
  if(direction == BULLISH && stop_loss_price < entry_price)
    return NormalizeDouble(entry_price + risk_distance, Digits());
  if(direction == BEARISH && stop_loss_price > entry_price)
    return NormalizeDouble(entry_price - risk_distance, Digits());
  return 0.0;
}

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
  ENUM_ORDER_TYPE order_type = (direction == BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
  double profit = 0.0;
  if(!OrderCalcProfit(order_type,
                      _Symbol,
                      1.0,
                      entry_price,
                      stop_loss_price,
                      profit))
    return false;

  loss_per_lot_out = MathAbs(profit);
  return (MathIsValidNumber(loss_per_lot_out) && loss_per_lot_out > 0.0);
}

bool ResolveExecutionVolumePlan(SignalParams &signal_params,
                                const double entry_price,
                                const double stop_loss_price,
                                double &requested_volume_out,
                                double &normalized_volume_out,
                                string &reason_out)
{
  requested_volume_out = 0.0;
  normalized_volume_out = 0.0;
  reason_out = "";
  signal_params.execution_risk_plan_valid = false;
  signal_params.execution_risk_plan_reason = "";
  signal_params.execution_risk_target_amount = 0.0;
  signal_params.execution_expected_sl_loss = 0.0;
  signal_params.execution_expected_tp_profit = 0.0;
  signal_params.execution_raw_lot_size = 0.0;
  signal_params.execution_normalized_lot_size = 0.0;

  if(entry_price <= 0.0 || stop_loss_price <= 0.0 ||
     ResolveExecutionOneRTarget(signal_params.signal_type,
                                entry_price,
                                stop_loss_price) <= 0.0)
  {
    reason_out = "invalid_entry_stop_geometry";
    signal_params.execution_risk_plan_reason = reason_out;
    return false;
  }

  double configured_size = Lot_Strategy_Size;
  if(configured_size <= 0.0 || !MathIsValidNumber(configured_size))
  {
    reason_out = "lot_strategy_size_invalid";
    signal_params.execution_risk_plan_reason = reason_out;
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
      reason_out = "account_balance_percent_out_of_range";
      signal_params.execution_risk_plan_reason = reason_out;
      return false;
    }

    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(account_balance <= 0.0 || !MathIsValidNumber(account_balance))
    {
      reason_out = "account_balance_invalid";
      signal_params.execution_risk_plan_reason = reason_out;
      return false;
    }

    double risk_budget = account_balance * configured_size / 100.0;
    double loss_per_lot = 0.0;
    if(risk_budget <= 0.0 ||
       !ResolveExecutionLossPerLot(signal_params.signal_type,
                                  entry_price,
                                  stop_loss_price,
                                  loss_per_lot))
    {
      reason_out = "risk_budget_or_order_calc_profit_invalid";
      signal_params.execution_risk_plan_reason = reason_out;
      return false;
    }

    signal_params.execution_risk_target_amount = risk_budget;
    requested_volume_out = risk_budget / loss_per_lot;
  }
  else
  {
    reason_out = "lot_type_invalid";
    signal_params.execution_risk_plan_reason = reason_out;
    return false;
  }

  normalized_volume_out = NormalizeExecutionVolumeDown(_Symbol, requested_volume_out);
  if(normalized_volume_out <= 0.0)
  {
    reason_out = "normalized_volume_below_broker_minimum_or_invalid";
    signal_params.execution_risk_plan_reason = reason_out;
    return false;
  }

  double take_profit_price = ResolveExecutionOneRTarget(signal_params.signal_type,
                                                        entry_price,
                                                        stop_loss_price);
  ENUM_ORDER_TYPE order_type =
    (signal_params.signal_type == BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
  double stop_profit = 0.0;
  double target_profit = 0.0;
  if(!OrderCalcProfit(order_type,
                      _Symbol,
                      normalized_volume_out,
                      entry_price,
                      stop_loss_price,
                      stop_profit) ||
     !OrderCalcProfit(order_type,
                      _Symbol,
                      normalized_volume_out,
                      entry_price,
                      take_profit_price,
                      target_profit))
  {
    reason_out = "normalized_order_calc_profit_failed";
    signal_params.execution_risk_plan_reason = reason_out;
    return false;
  }

  double expected_loss = MathAbs(stop_profit);
  if(Lot_Type == EXECUTION_LOT_ACCOUNT_BALANCE_PERCENT &&
     expected_loss > signal_params.execution_risk_target_amount * (1.0 + 1e-9))
  {
    reason_out = "normalized_volume_exceeds_risk_budget";
    signal_params.execution_risk_plan_reason = reason_out;
    return false;
  }

  signal_params.execution_risk_plan_valid = true;
  signal_params.execution_risk_plan_reason = "ok";
  signal_params.execution_expected_sl_loss = expected_loss;
  signal_params.execution_expected_tp_profit = target_profit;
  signal_params.execution_raw_lot_size = requested_volume_out;
  signal_params.execution_normalized_lot_size = normalized_volume_out;
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
