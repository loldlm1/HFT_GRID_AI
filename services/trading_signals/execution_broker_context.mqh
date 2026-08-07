//+------------------------------------------------------------------+
//|                    trading_signals/execution_broker_context.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_CONTEXT_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_CONTEXT_MQH_

const int BROKER_CONSTRAINT_REFRESH_SECONDS = 60;

int NextBrokerExecutionCheckSequence(PivotSignal &signal)
{
  signal.execution.last_check_sequence++;
  return signal.execution.last_check_sequence;
}

void ExecutionCheckBlock(BrokerExecutionCheck &check,
                         const string source,
                         const string reason)
{
  if(check.block_source == "")
  {
    check.block_source = source;
    check.block_reason = reason;
  }
  check.allowed = false;
}

bool BrokerConstraintsNeedRefresh()
{
  if(g_symbol_constraints.symbol != _Symbol ||
     g_symbol_constraints.point_size <= 0.0 ||
     g_symbol_constraints.volume_step <= 0.0 ||
     g_symbol_constraints.last_refresh <= 0)
    return true;
  return ((TimeCurrent() - g_symbol_constraints.last_refresh) >=
          BROKER_CONSTRAINT_REFRESH_SECONDS);
}

bool SymbolTradeModeAllowsExecution(const long trade_mode,
                                    const SignalTypes direction)
{
  if(trade_mode == SYMBOL_TRADE_MODE_FULL)
    return true;
  if(trade_mode == SYMBOL_TRADE_MODE_LONGONLY)
    return (direction == BULLISH);
  if(trade_mode == SYMBOL_TRADE_MODE_SHORTONLY)
    return (direction == BEARISH);
  return false;
}

MarketStatusTypes MarketStatusFromSymbolTradeMode(const long trade_mode)
{
  if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
    return MARKET_STATUS_BROKER_DISABLED;
  if(trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY)
    return MARKET_STATUS_BROKER_CLOSEONLY;
  return MARKET_STATUS_ACTIVE;
}

ENUM_ORDER_TYPE ExecutionOrderType(const SignalTypes direction)
{
  return (direction == BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
}

bool ExecutionFullFillPolicyAvailable(const string symbol)
{
  long filling_mode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
  return (filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK;
}

bool ExecutionOrderCheckRetcodeAllowed(const ulong retcode)
{
  // OrderCheck reports a successful verification with retcode 0 (typically
  // comment "Done"); send retcodes use the explicit completed/placed values.
  if(retcode == 0 ||
     retcode == TRADE_RETCODE_DONE ||
     retcode == TRADE_RETCODE_PLACED)
    return true;
  return false;
}

double ExecutionPriceDistancePoints(const double first_price,
                                    const double second_price,
                                    const double point_size)
{
  if(first_price <= 0.0 || second_price <= 0.0 || point_size <= 0.0)
    return 0.0;
  return MathAbs(first_price - second_price) / point_size;
}

bool ExecutionGeometryValid(const SignalTypes direction,
                            const double entry_price,
                            const double stop_loss_price,
                            const double take_profit_price)
{
  if(entry_price <= 0.0 || stop_loss_price <= 0.0 || take_profit_price <= 0.0)
    return false;
  if(direction == BULLISH)
    return (stop_loss_price < entry_price && take_profit_price > entry_price);
  if(direction == BEARISH)
    return (stop_loss_price > entry_price && take_profit_price < entry_price);
  return false;
}

bool ExecutionPriceDistanceOneRValid(const double risk_distance_points,
                                     const double reward_distance_points,
                                     const double ratio)
{
  if(risk_distance_points <= 0.0 ||
     reward_distance_points <= 0.0 ||
     !MathIsValidNumber(ratio))
    return false;
  double tolerance = MathMax(1e-7,
                             MathMax(risk_distance_points,
                                     reward_distance_points) * 1e-10);
  return MathAbs(risk_distance_points - reward_distance_points) <= tolerance &&
         MathAbs(ratio - 1.0) <= 1e-9;
}

bool ExecutionProtectionGeometryValid(const SignalTypes direction,
                                      const double bid,
                                      const double ask,
                                      const double stop_loss_price,
                                      const double take_profit_price)
{
  if(bid <= 0.0 || ask <= 0.0 || ask < bid ||
     stop_loss_price <= 0.0 || take_profit_price <= 0.0)
    return false;
  if(direction == BULLISH)
    return stop_loss_price < bid && take_profit_price > ask;
  if(direction == BEARISH)
    return stop_loss_price > ask && take_profit_price < bid;
  return false;
}

bool ExecutionVolumeMatchesBroker(const BrokerExecutionCheck &check)
{
  if(check.requested_volume <= 0.0 || check.normalized_volume <= 0.0 ||
     check.volume_min <= 0.0 || check.volume_max <= 0.0 ||
     check.volume_step <= 0.0)
    return false;
  if(check.normalized_volume + 1e-12 < check.volume_min ||
     check.normalized_volume > check.volume_max + 1e-12 ||
     check.normalized_volume > check.requested_volume + 1e-12)
    return false;

  double steps = check.normalized_volume / check.volume_step;
  return (MathAbs(steps - MathRound(steps)) <= 1e-6);
}

bool RunExecutionOrderCheck(BrokerExecutionCheck &check)
{
  MqlTradeRequest request;
  MqlTradeCheckResult result;
  ZeroMemory(request);
  ZeroMemory(result);

  request.action = TRADE_ACTION_DEAL;
  request.symbol = check.symbol;
  request.magic = g_execution_magic;
  request.volume = check.normalized_volume;
  request.price = check.planned_entry_price;
  request.sl = check.stop_loss_price;
  request.tp = check.take_profit_price;
  request.type = ExecutionOrderType(check.direction);
  request.type_filling = ORDER_FILLING_FOK;
  request.type_time = ORDER_TIME_GTC;

  check.order_check_performed = true;
  if(!OrderCheck(request, result))
  {
    check.order_check_retcode = result.retcode;
    check.order_check_comment = result.comment;
    ExecutionCheckBlock(check,
                        "order_check",
                        StringFormat("api_failed|retcode=%I64u|error=%d|comment=%s",
                                     result.retcode,
                                     GetLastError(),
                                     result.comment));
    return false;
  }

  check.order_check_retcode = result.retcode;
  check.order_check_comment = result.comment;
  check.order_check_allowed =
    ExecutionOrderCheckRetcodeAllowed(result.retcode);
  if(!check.order_check_allowed)
  {
    ExecutionCheckBlock(check,
                        "order_check",
                        StringFormat("retcode=%I64u|comment=%s",
                                     result.retcode,
                                     result.comment));
    return false;
  }
  return true;
}

bool CaptureBrokerExecutionCheck(const SignalTypes direction,
                                 const string phase,
                                 const int sequence,
                                 const datetime broker_time,
                                 const MqlTick &observed_tick,
                                 const double entry_price,
                                 const double stop_loss_price,
                                 const double take_profit_price,
                                 const double requested_volume,
                                 const double normalized_volume,
                                 const double risk_budget_amount,
                                 const double quote_expected_stop_loss,
                                 const double quote_expected_take_profit,
                                 const double quote_expected_ratio,
                                 const double risk_budget_utilization_ratio,
                                 const bool refresh_constraints_for_send,
                                 BrokerExecutionCheck &check)
{
  check.Reset();
  check.phase = phase;
  check.sequence = sequence;
  check.broker_time = broker_time > 0 ? broker_time : TimeCurrent();
  check.symbol = _Symbol;
  check.direction = direction;
  check.planned_entry_price = entry_price;
  check.stop_loss_price = stop_loss_price;
  check.take_profit_price = take_profit_price;
  check.risk_budget_amount = risk_budget_amount;
  check.requested_volume = requested_volume;
  check.normalized_volume = normalized_volume;
  check.quote_expected_stop_loss = quote_expected_stop_loss;
  check.quote_expected_take_profit = quote_expected_take_profit;
  check.quote_expected_reward_risk_ratio = quote_expected_ratio;
  check.risk_budget_utilization_ratio = risk_budget_utilization_ratio;
  check.allowed = true;

  if(observed_tick.bid <= 0.0 ||
     observed_tick.ask <= 0.0 ||
     observed_tick.ask < observed_tick.bid)
  {
    ExecutionCheckBlock(check, "market_tick", "bid_or_ask_invalid");
  }
  else
  {
    check.bid = observed_tick.bid;
    check.ask = observed_tick.ask;
  }

  bool refresh_constraints = refresh_constraints_for_send ||
                             BrokerConstraintsNeedRefresh();
  if(refresh_constraints &&
     !RefreshSymbolTradingConstraints(check.symbol, g_symbol_constraints))
  {
    ExecutionCheckBlock(check, "broker_constraints", "refresh_failed");
  }

  check.point_size = g_symbol_constraints.point_size;
  check.trade_tick_size = g_symbol_constraints.tick_size;
  check.stops_distance_points = g_symbol_constraints.stops_level_points;
  check.freeze_distance_points = g_symbol_constraints.freeze_level_points;
  check.volume_min = g_symbol_constraints.min_volume;
  check.volume_max = g_symbol_constraints.max_volume;
  check.volume_step = g_symbol_constraints.volume_step;
  if(check.point_size > 0.0 && check.ask > 0.0 && check.bid > 0.0)
    check.spread_points = (check.ask - check.bid) / check.point_size;
  else
    ExecutionCheckBlock(check, "market_price", "bid_ask_or_point_invalid");

  check.risk_distance_points =
    ExecutionPriceDistancePoints(entry_price,
                                 stop_loss_price,
                                 check.point_size);
  check.reward_distance_points =
    ExecutionPriceDistancePoints(entry_price,
                                 take_profit_price,
                                 check.point_size);
  if(check.risk_distance_points > 0.0)
    check.price_reward_risk_ratio =
      check.reward_distance_points / check.risk_distance_points;

  check.account_margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  check.account_margin_mode_supported =
    (check.account_margin_mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  if(!check.account_margin_mode_supported)
    ExecutionCheckBlock(check,
                        "account_margin_mode",
                        StringFormat("unsupported=%d|required=%d",
                                     check.account_margin_mode,
                                     ACCOUNT_MARGIN_MODE_RETAIL_HEDGING));

  check.symbol_trade_mode = SymbolInfoInteger(check.symbol, SYMBOL_TRADE_MODE);
  check.symbol_trade_mode_allowed =
    SymbolTradeModeAllowsExecution(check.symbol_trade_mode, check.direction);
  if(!check.symbol_trade_mode_allowed)
    ExecutionCheckBlock(check,
                        "symbol_trade_mode",
                        StringFormat("mode=%d|direction=%s",
                                     check.symbol_trade_mode,
                                     EnumToString(check.direction)));

  check.fok_supported = ExecutionFullFillPolicyAvailable(check.symbol);
  if(!check.fok_supported)
    ExecutionCheckBlock(check,
                        "filling_mode",
                        "full_fill_fok_required");

  MarketStatusTypes status = MarketStatusFromSymbolTradeMode(check.symbol_trade_mode);
  MarketStatusUpdate(status,
                     StringFormat("symbol_trade_mode=%d", check.symbol_trade_mode));

  check.market_session_open =
    IsSymbolTradeSessionOpen(check.symbol, check.broker_time);
  if(!check.market_session_open)
    ExecutionCheckBlock(check, "market_session", "actual_broker_session_closed");

  check.account_trade_allowed =
    (AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) > 0);
  check.account_expert_trade_allowed =
    (AccountInfoInteger(ACCOUNT_TRADE_EXPERT) > 0);
  check.terminal_trade_allowed =
    (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) > 0);
  check.mql_trade_allowed = (MQLInfoInteger(MQL_TRADE_ALLOWED) > 0);
  if(!check.account_trade_allowed ||
     !check.account_expert_trade_allowed ||
     !check.terminal_trade_allowed ||
     !check.mql_trade_allowed)
    ExecutionCheckBlock(check,
                        "algo_trading",
                        "account_terminal_or_mql_trade_permission_disabled");

  check.geometry_valid =
    ExecutionGeometryValid(check.direction,
                           entry_price,
                           stop_loss_price,
                           take_profit_price) &&
    ExecutionProtectionGeometryValid(check.direction,
                                     check.bid,
                                     check.ask,
                                     stop_loss_price,
                                     take_profit_price) &&
    ExecutionPriceDistanceOneRValid(check.risk_distance_points,
                                    check.reward_distance_points,
                                    check.price_reward_risk_ratio);
  if(!check.geometry_valid)
    ExecutionCheckBlock(check,
                        "sl_tp_geometry",
                        "directional_or_exact_one_r_geometry_invalid");

  double protection_reference = check.direction == BULLISH
                                ? check.bid
                                : check.ask;
  double stop_points = ExecutionPriceDistancePoints(protection_reference,
                                                    stop_loss_price,
                                                    check.point_size);
  double target_points = ExecutionPriceDistancePoints(protection_reference,
                                                      take_profit_price,
                                                      check.point_size);
  check.stop_distance_valid =
    (check.geometry_valid && check.point_size > 0.0 &&
     stop_points + 1e-9 >= check.stops_distance_points &&
     target_points + 1e-9 >= check.stops_distance_points);
  if(!check.stop_distance_valid)
    ExecutionCheckBlock(check,
                        "stops_distance",
                        StringFormat("sl=%.2f|tp=%.2f|min=%.2f",
                                     stop_points,
                                     target_points,
                                     check.stops_distance_points));

  check.freeze_distance_valid =
    (check.geometry_valid && check.point_size > 0.0 &&
     stop_points + 1e-9 >= check.freeze_distance_points &&
     target_points + 1e-9 >= check.freeze_distance_points);
  if(!check.freeze_distance_valid)
    ExecutionCheckBlock(check,
                        "freeze_distance",
                        StringFormat("sl=%.2f|tp=%.2f|min=%.2f",
                                     stop_points,
                                     target_points,
                                     check.freeze_distance_points));

  check.volume_valid = ExecutionVolumeMatchesBroker(check);
  if(!check.volume_valid)
    ExecutionCheckBlock(check,
                        "volume",
                        StringFormat("requested=%.8f|normalized=%.8f|min=%.8f|max=%.8f|step=%.8f",
                                     check.requested_volume,
                                     check.normalized_volume,
                                     check.volume_min,
                                     check.volume_max,
                                     check.volume_step));

  check.account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
  check.free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  if(check.volume_valid && check.geometry_valid)
  {
    double required_margin = 0.0;
    if(!OrderCalcMargin(ExecutionOrderType(check.direction),
                        check.symbol,
                        check.normalized_volume,
                        entry_price,
                        required_margin))
    {
      ExecutionCheckBlock(check, "margin", "order_calc_margin_failed");
    }
    else
    {
      check.required_margin = required_margin;
      check.margin_valid = (check.free_margin > 0.0 &&
                            check.free_margin + 1e-8 >= required_margin);
      if(!check.margin_valid)
        ExecutionCheckBlock(check,
                            "margin",
                            StringFormat("free=%.2f|required=%.2f",
                                         check.free_margin,
                                         required_margin));
    }
  }

  return check.allowed;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_CONTEXT_MQH_
