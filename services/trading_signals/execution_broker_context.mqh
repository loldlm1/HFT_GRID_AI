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

double BrokerExecutionEstimateMarginPerLot(const SignalTypes direction)
{
  double margin_per_lot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
  if(margin_per_lot > 0.0)
    return margin_per_lot;

  double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
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
  snapshot.market_allows_signal         = MarketStatusAllowsSignalAttempts();
  snapshot.market_allows_broker_actions = MarketStatusAllowsBrokerActions();
  snapshot.protection_allows_signal     = ProtectionRiskAllowsSignalAttempt();
  snapshot.session_allows_signal        = SessionTimeFilterAllowsSignalAttempt();
  snapshot.daily_signal_allows          = DailySignalLimitAllowsAttempt(direction);
  snapshot.direction_allowed            = DirectionAllowed(direction);
  snapshot.concurrency_allows           = SignalConcurrencyAllowsAttempt(direction);

  if(requested_volume > 0.0)
  {
    snapshot.normalized_volume = NormalizeVolumeForSymbol(snapshot.symbol, requested_volume);
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

#endif // _SERVICES_TRADING_SIGNALS_EXECUTION_BROKER_CONTEXT_MQH_
