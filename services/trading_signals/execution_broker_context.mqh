//+------------------------------------------------------------------+
//|                    trading_signals/execution_broker_context.mqh |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_CONTEXT_MQH_
#define _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_CONTEXT_MQH_

const int BROKER_EXECUTION_CONSTRAINT_REFRESH_SECONDS = 60;

struct BrokerExecutionEligibility
{
  bool   allowed;
  string block_source;
  string block_reason;

  BrokerExecutionEligibility()
  {
    allowed      = false;
    block_source = "";
    block_reason = "";
  }

  BrokerExecutionEligibility(const BrokerExecutionEligibility &other)
  {
    allowed      = other.allowed;
    block_source = other.block_source;
    block_reason = other.block_reason;
  }
};

struct BrokerExecutionSnapshot
{
  string            symbol;
  SignalTypes       direction;
  MarketStatusTypes market_status;

  double bid;
  double ask;
  double point_size;
  double spread_points;
  double min_stop_distance_points;
  double freeze_level_points;
  double stops_level_points;
  datetime constraints_last_refresh;

  bool terminal_algo_allowed;
  bool market_session_open;
  bool market_allows_signal;
  bool market_allows_broker_actions;
  bool protection_allows_signal;
  bool session_allows_signal;
  bool daily_signal_allows;
  bool direction_allowed;
  bool concurrency_allows;

  double requested_volume;
  double normalized_volume;
  bool   volume_valid;

  double free_margin;
  double margin_per_lot;
  double required_margin;
  bool   margin_available;

  bool   valid;
  string invalid_reason;

  BrokerExecutionSnapshot()
  {
    symbol                       = "";
    direction                    = NO_SIGNAL;
    market_status                = MARKET_STATUS_ACTIVE;
    bid                          = 0.0;
    ask                          = 0.0;
    point_size                   = 0.0;
    spread_points                = 0.0;
    min_stop_distance_points     = 0.0;
    freeze_level_points          = 0.0;
    stops_level_points           = 0.0;
    constraints_last_refresh     = 0;
    terminal_algo_allowed        = false;
    market_session_open          = false;
    market_allows_signal         = false;
    market_allows_broker_actions = false;
    protection_allows_signal     = false;
    session_allows_signal        = false;
    daily_signal_allows          = false;
    direction_allowed            = false;
    concurrency_allows           = false;
    requested_volume             = 0.0;
    normalized_volume            = 0.0;
    volume_valid                 = false;
    free_margin                  = 0.0;
    margin_per_lot               = 0.0;
    required_margin              = 0.0;
    margin_available             = false;
    valid                        = false;
    invalid_reason               = "";
  }

  BrokerExecutionSnapshot(const BrokerExecutionSnapshot &other)
  {
    symbol                       = other.symbol;
    direction                    = other.direction;
    market_status                = other.market_status;
    bid                          = other.bid;
    ask                          = other.ask;
    point_size                   = other.point_size;
    spread_points                = other.spread_points;
    min_stop_distance_points     = other.min_stop_distance_points;
    freeze_level_points          = other.freeze_level_points;
    stops_level_points           = other.stops_level_points;
    constraints_last_refresh     = other.constraints_last_refresh;
    terminal_algo_allowed        = other.terminal_algo_allowed;
    market_session_open          = other.market_session_open;
    market_allows_signal         = other.market_allows_signal;
    market_allows_broker_actions = other.market_allows_broker_actions;
    protection_allows_signal     = other.protection_allows_signal;
    session_allows_signal        = other.session_allows_signal;
    daily_signal_allows          = other.daily_signal_allows;
    direction_allowed            = other.direction_allowed;
    concurrency_allows           = other.concurrency_allows;
    requested_volume             = other.requested_volume;
    normalized_volume            = other.normalized_volume;
    volume_valid                 = other.volume_valid;
    free_margin                  = other.free_margin;
    margin_per_lot               = other.margin_per_lot;
    required_margin              = other.required_margin;
    margin_available             = other.margin_available;
    valid                        = other.valid;
    invalid_reason               = other.invalid_reason;
  }
};

bool BrokerExecutionConstraintsNeedRefresh()
{
  if(g_symbol_constraints.symbol != _Symbol)
    return true;
  if(g_symbol_constraints.point_size <= 0.0 ||
     g_symbol_constraints.tick_size <= 0.0 ||
     g_symbol_constraints.tick_value <= 0.0)
    return true;
  if(g_symbol_constraints.last_refresh <= 0)
    return true;

  datetime now = TimeCurrent();
  if(now <= 0)
    return false;

  return ((now - g_symbol_constraints.last_refresh) >= BROKER_EXECUTION_CONSTRAINT_REFRESH_SECONDS);
}

double BrokerExecutionNormalizeVolume(const double volume)
{
  if(volume <= 0.0)
    return 0.0;

  if(g_symbol_constraints.symbol != _Symbol ||
     g_symbol_constraints.min_volume <= 0.0 ||
     g_symbol_constraints.max_volume <= 0.0 ||
     g_symbol_constraints.volume_step <= 0.0)
    return NormalizeVolumeForSymbol(_Symbol, volume);

  double normalized = volume;

  if(normalized < g_symbol_constraints.min_volume)
    normalized = g_symbol_constraints.min_volume;
  if(normalized > g_symbol_constraints.max_volume)
    normalized = g_symbol_constraints.max_volume;

  double steps = MathFloor((normalized + 1e-12) / g_symbol_constraints.volume_step);
  normalized   = steps * g_symbol_constraints.volume_step;

  int vol_digits = 0;
  if(g_symbol_constraints.volume_step < 1.0)
  {
    vol_digits = (int)MathRound(-MathLog10(g_symbol_constraints.volume_step));
    if(vol_digits < 0)
      vol_digits = 0;
  }

  return NormalizeDouble(normalized, vol_digits);
}

double BrokerExecutionEstimateMarginPerLot(const SignalTypes direction)
{
  double margin_per_lot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
  if(margin_per_lot > 0.0)
    return margin_per_lot;

  double contract_size = g_symbol_constraints.contract_size;
  if(contract_size <= 0.0)
    contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

  double price = g_ask;
  if(direction == BEARISH)
    price = g_bid;
  if(price <= 0.0)
    price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  if(price <= 0.0)
    price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

  double leverage = (double)AccountInfoInteger(ACCOUNT_LEVERAGE);
  if(contract_size <= 0.0 || price <= 0.0 || leverage <= 0.0)
    return 0.0;

  return (contract_size * price) / leverage;
}

void BrokerExecutionBlock(BrokerExecutionEligibility &eligibility,
                          const string source,
                          const string reason)
{
  eligibility.allowed      = false;
  eligibility.block_source = source;
  eligibility.block_reason = reason;
}

void BrokerExecutionAllow(BrokerExecutionEligibility &eligibility)
{
  eligibility.allowed      = true;
  eligibility.block_source = "";
  eligibility.block_reason = "";
}

bool CaptureBrokerExecutionSnapshot(const SignalTypes direction,
                                    const double requested_volume,
                                    BrokerExecutionSnapshot &snapshot)
{
  snapshot = BrokerExecutionSnapshot();
  snapshot.symbol           = _Symbol;
  snapshot.direction        = direction;
  snapshot.market_status    = MarketStatusGet();
  snapshot.bid              = g_bid;
  snapshot.ask              = g_ask;
  snapshot.spread_points    = g_points_spread;
  snapshot.requested_volume = requested_volume;

  if(snapshot.symbol == "")
  {
    snapshot.invalid_reason = "symbol_empty";
    return false;
  }

  if(BrokerExecutionConstraintsNeedRefresh())
  {
    if(!RefreshSymbolTradingConstraints(snapshot.symbol, g_symbol_constraints))
    {
      snapshot.invalid_reason = "constraints_unavailable";
      return false;
    }
  }

  snapshot.point_size               = g_symbol_constraints.point_size;
  snapshot.min_stop_distance_points = MinBrokerDistancePoints(g_symbol_constraints);
  snapshot.freeze_level_points      = g_symbol_constraints.freeze_level_points;
  snapshot.stops_level_points       = g_symbol_constraints.stops_level_points;
  snapshot.constraints_last_refresh = g_symbol_constraints.last_refresh;

  if(snapshot.point_size <= 0.0)
  {
    snapshot.invalid_reason = "point_size_invalid";
    return false;
  }

  if(snapshot.bid <= 0.0 || snapshot.ask <= 0.0)
  {
    snapshot.invalid_reason = "bid_ask_invalid";
    return false;
  }

  snapshot.terminal_algo_allowed        = TerminalAlgoTradingEnabled();
  snapshot.market_session_open          = IsMarketOpen();
  snapshot.market_allows_signal         = MarketStatusAllowsSignalAttempts();
  snapshot.market_allows_broker_actions = MarketStatusAllowsBrokerActions();
  snapshot.protection_allows_signal     = ProtectionRiskAllowsSignalAttempt();
  snapshot.session_allows_signal        = SessionTimeFilterAllowsSignalAttempt();
  snapshot.daily_signal_allows          = DailySignalLimitAllowsAttempt(direction);
  snapshot.direction_allowed            = DirectionAllowed(direction);
  snapshot.concurrency_allows           = SignalConcurrencyAllowsAttempt(direction);

  if(requested_volume > 0.0)
  {
    snapshot.normalized_volume = BrokerExecutionNormalizeVolume(requested_volume);
    snapshot.volume_valid = (snapshot.normalized_volume > 0.0);
  }

  snapshot.free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  snapshot.margin_per_lot = BrokerExecutionEstimateMarginPerLot(direction);
  if(snapshot.normalized_volume > 0.0 && snapshot.margin_per_lot > 0.0)
    snapshot.required_margin = snapshot.margin_per_lot * snapshot.normalized_volume;
  snapshot.margin_available = (snapshot.required_margin <= 0.0 ||
                               snapshot.free_margin <= 0.0 ||
                               snapshot.free_margin >= snapshot.required_margin);

  snapshot.valid = true;
  return true;
}

double BrokerExecutionEntrySidePrice(const BrokerExecutionSnapshot &snapshot)
{
  if(snapshot.direction == BULLISH)
    return snapshot.ask;
  if(snapshot.direction == BEARISH)
    return snapshot.bid;
  return 0.0;
}

double BrokerExecutionPriceDistancePoints(const BrokerExecutionSnapshot &snapshot,
                                          const double first_price,
                                          const double second_price)
{
  if(snapshot.point_size <= 0.0 || first_price <= 0.0 || second_price <= 0.0)
    return 0.0;

  return MathAbs(first_price - second_price) / snapshot.point_size;
}

bool BrokerExecutionValidateLegDistance(const BrokerExecutionSnapshot &snapshot,
                                        const double reference_price,
                                        const double target_price,
                                        const string source,
                                        BrokerExecutionEligibility &eligibility)
{
  if(reference_price <= 0.0 || target_price <= 0.0)
    return true;

  double min_distance = snapshot.min_stop_distance_points;
  if(min_distance <= 0.0)
    return true;

  double distance_points = BrokerExecutionPriceDistancePoints(snapshot,
                                                             reference_price,
                                                             target_price);
  if(distance_points + 1e-9 >= min_distance)
    return true;

  BrokerExecutionBlock(eligibility,
                       "broker_distance",
                       StringFormat("%s=%.2f<%.2f", source, distance_points, min_distance));
  return false;
}

bool EvaluateLocalExecutionLegEligibility(const SignalParams &signal_params,
                                          const ExecutionLegState &leg_state,
                                          const double requested_volume,
                                          BrokerExecutionSnapshot &snapshot,
                                          BrokerExecutionEligibility &eligibility)
{
  eligibility = BrokerExecutionEligibility();

  if(!CaptureBrokerExecutionSnapshot(signal_params.signal_type,
                                     requested_volume,
                                     snapshot))
  {
    BrokerExecutionBlock(eligibility,
                         "broker_snapshot",
                         snapshot.invalid_reason);
    return false;
  }

  if(signal_params.signal_type != BULLISH && signal_params.signal_type != BEARISH)
  {
    BrokerExecutionBlock(eligibility,
                         "direction",
                         "invalid_signal_direction");
    return false;
  }

  if(!snapshot.terminal_algo_allowed)
  {
    BrokerExecutionBlock(eligibility,
                         "algo_trading",
                         "terminal_or_mql_trading_disabled");
    return false;
  }

  if(!snapshot.market_allows_signal)
  {
    BrokerExecutionBlock(eligibility,
                         "market_status",
                         MarketStatusToString(snapshot.market_status));
    return false;
  }

  if(!snapshot.market_session_open)
  {
    BrokerExecutionBlock(eligibility,
                         "market_session",
                         "market_closed");
    return false;
  }

  if(!snapshot.protection_allows_signal)
  {
    BrokerExecutionBlock(eligibility,
                         "protection_risk",
                         "protection_filter_blocked");
    return false;
  }

  if(!snapshot.session_allows_signal)
  {
    BrokerExecutionBlock(eligibility,
                         "session_time_filter",
                         "outside_configured_session");
    return false;
  }

  if(snapshot.spread_points > Max_Spread)
  {
    BrokerExecutionBlock(eligibility,
                         "spread_guard",
                         StringFormat("spread=%.1f>%.1f",
                                      snapshot.spread_points,
                                      Max_Spread));
    return false;
  }

  double entry_side_price = BrokerExecutionEntrySidePrice(snapshot);
  if(entry_side_price <= 0.0)
  {
    BrokerExecutionBlock(eligibility,
                         "price",
                         "entry_side_price_invalid");
    return false;
  }

  if(leg_state.entry_reference_price <= 0.0)
  {
    BrokerExecutionBlock(eligibility,
                         "entry_reference",
                         "entry_reference_invalid");
    return false;
  }

  if(!BrokerExecutionValidateLegDistance(snapshot,
                                         leg_state.entry_reference_price,
                                         leg_state.take_profit_price,
                                         "tp_distance",
                                         eligibility))
    return false;

  if(!BrokerExecutionValidateLegDistance(snapshot,
                                         leg_state.entry_reference_price,
                                         leg_state.next_level_price,
                                         "next_distance",
                                         eligibility))
    return false;

  if(leg_state.opens_position)
  {
    if(requested_volume <= 0.0 || !snapshot.volume_valid)
    {
      BrokerExecutionBlock(eligibility,
                           "volume",
                           "normalized_volume_invalid");
      return false;
    }

    if(snapshot.free_margin <= 0.0)
    {
      BrokerExecutionBlock(eligibility,
                           "margin",
                           "free_margin_unavailable");
      return false;
    }

    if(snapshot.margin_per_lot <= 0.0)
    {
      BrokerExecutionBlock(eligibility,
                           "margin",
                           "margin_per_lot_unavailable");
      return false;
    }

    if(!snapshot.margin_available)
    {
      BrokerExecutionBlock(eligibility,
                           "margin",
                           StringFormat("margin=%.2f<%.2f",
                                        snapshot.free_margin,
                                        snapshot.required_margin));
      return false;
    }
  }

  BrokerExecutionAllow(eligibility);
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_CONTEXT_MQH_
