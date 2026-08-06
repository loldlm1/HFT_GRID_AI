//+------------------------------------------------------------------+
//|                                      execution_lot_math          |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_

int ExecutionVolumeDigits(const double volume_step)
{
  if(volume_step <= 0.0)
    return 0;
  for(int digits = 0; digits <= 8; digits++)
  {
    double scaled = volume_step * MathPow(10.0, digits);
    if(MathAbs(scaled - MathRound(scaled)) <= 1e-8)
      return digits;
  }
  return 8;
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

bool ResolveExecutionQuoteProfit(const SignalTypes direction,
                                 const double volume,
                                 const double entry_price,
                                 const double exit_price,
                                 double &profit_out)
{
  profit_out = 0.0;
  if((direction != BULLISH && direction != BEARISH) ||
     volume <= 0.0 || entry_price <= 0.0 || exit_price <= 0.0)
    return false;

  ENUM_ORDER_TYPE order_type = direction == BULLISH
                               ? ORDER_TYPE_BUY
                               : ORDER_TYPE_SELL;
  if(!OrderCalcProfit(order_type,
                      _Symbol,
                      volume,
                      entry_price,
                      exit_price,
                      profit_out))
    return false;
  return MathIsValidNumber(profit_out);
}

bool ResolveExecutionVolumePlan(const SignalTypes direction,
                                const double entry_price,
                                const double stop_loss_price,
                                const double take_profit_price,
                                double &requested_volume_out,
                                double &normalized_volume_out,
                                double &risk_budget_amount_out,
                                double &quote_expected_stop_loss_out,
                                double &quote_expected_take_profit_out,
                                double &quote_expected_ratio_out,
                                double &risk_budget_utilization_out,
                                string &reason_out)
{
  requested_volume_out = 0.0;
  normalized_volume_out = 0.0;
  risk_budget_amount_out = 0.0;
  quote_expected_stop_loss_out = 0.0;
  quote_expected_take_profit_out = 0.0;
  quote_expected_ratio_out = 0.0;
  risk_budget_utilization_out = 0.0;
  reason_out = "";

  bool geometry_valid = false;
  if(direction == BULLISH)
    geometry_valid = stop_loss_price > 0.0 &&
                     stop_loss_price < entry_price &&
                     take_profit_price > entry_price;
  else if(direction == BEARISH)
    geometry_valid = stop_loss_price > entry_price &&
                     take_profit_price > 0.0 &&
                     take_profit_price < entry_price;
  if(entry_price <= 0.0 || !geometry_valid)
  {
    reason_out = "INVALID_ENTRY_SL_TP_GEOMETRY";
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
  else if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
  {
    if(configured_size > 100.0)
    {
      reason_out = "REFERENCE_BALANCE_PERCENT_OUT_OF_RANGE";
      return false;
    }

    double stop_profit_per_lot = 0.0;
    double loss_per_lot = 0.0;
    if(!ResolveExecutionQuoteProfit(direction,
                                    1.0,
                                    entry_price,
                                    stop_loss_price,
                                    stop_profit_per_lot) ||
       stop_profit_per_lot >= 0.0)
    {
      reason_out = "STOP_LOSS_ORDER_CALC_PROFIT_INVALID";
      return false;
    }
    loss_per_lot = MathAbs(stop_profit_per_lot);

    risk_budget_amount_out =
      PIVOT_EXECUTION_REFERENCE_BALANCE * configured_size / 100.0;
    if(risk_budget_amount_out <= 0.0 ||
       !MathIsValidNumber(risk_budget_amount_out) ||
       loss_per_lot <= 0.0)
    {
      reason_out = "RISK_BUDGET_INVALID";
      return false;
    }
    requested_volume_out = risk_budget_amount_out / loss_per_lot;
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

  double stop_profit = 0.0;
  double take_profit = 0.0;
  if(!ResolveExecutionQuoteProfit(direction,
                                  normalized_volume_out,
                                  entry_price,
                                  stop_loss_price,
                                  stop_profit) ||
     !ResolveExecutionQuoteProfit(direction,
                                  normalized_volume_out,
                                  entry_price,
                                  take_profit_price,
                                  take_profit) ||
     stop_profit >= 0.0 || take_profit <= 0.0)
  {
    reason_out = "NORMALIZED_ORDER_CALC_PROFIT_FAILED";
    return false;
  }

  quote_expected_stop_loss_out = MathAbs(stop_profit);
  quote_expected_take_profit_out = MathAbs(take_profit);
  if(quote_expected_stop_loss_out <= 0.0 ||
     quote_expected_take_profit_out <= 0.0)
  {
    reason_out = "QUOTE_EXPECTED_MONEY_INVALID";
    return false;
  }
  quote_expected_ratio_out =
    quote_expected_take_profit_out / quote_expected_stop_loss_out;
  if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT &&
     quote_expected_stop_loss_out > risk_budget_amount_out * (1.0 + 1e-9))
  {
    reason_out = "NORMALIZED_VOLUME_EXCEEDS_RISK_BUDGET";
    return false;
  }
  if(Lot_Type == EXECUTION_LOT_REFERENCE_BALANCE_PERCENT)
    risk_budget_utilization_out =
      quote_expected_stop_loss_out / risk_budget_amount_out;
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_LOT_MATH_MQH_
