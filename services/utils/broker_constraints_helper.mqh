//+------------------------------------------------------------------+
//|                    microservices/utils/broker_constraints_helper |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_BROKER_CONSTRAINTS_HELPER_MQH_
#define _MICROSERVICES_UTILS_BROKER_CONSTRAINTS_HELPER_MQH_

// Reusable container for broker trading limitations (freeze, stops, volumes).
// This struct stores the latest snapshot for a symbol and can be refreshed
// whenever market conditions change (e.g., symbol specification update).
struct SymbolTradingConstraints
{
  string  symbol;
  double  point_size;
  double  tick_size;
  double  tick_value;
  double  contract_size;
  double  min_volume;
  double  max_volume;
  double  volume_step;
  double  freeze_level_points;
  double  stops_level_points;
  double  min_stop_distance_points;
  datetime last_refresh;

  SymbolTradingConstraints()
  {
    symbol               = "";
    point_size           = 0.0;
    tick_size            = 0.0;
    tick_value           = 0.0;
    contract_size        = 0.0;
    min_volume           = 0.0;
    max_volume           = 0.0;
    volume_step          = 0.0;
    freeze_level_points  = 0.0;
    stops_level_points   = 0.0;
    min_stop_distance_points = 0.0;
    last_refresh         = 0;
  }
};

// Refreshes the structure with the latest broker specification for a symbol.
// Returns false if any of the critical specification calls fail.
bool RefreshSymbolTradingConstraints(const string symbol, SymbolTradingConstraints &constraints)
{
  if(symbol == "")
    return false;

  constraints.symbol = symbol;

  constraints.point_size          = SymbolInfoDouble(symbol, SYMBOL_POINT);
  constraints.tick_size           = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
  constraints.tick_value          = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
  constraints.contract_size       = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
  constraints.min_volume          = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
  constraints.max_volume          = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
  constraints.volume_step         = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
  constraints.freeze_level_points = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
  constraints.stops_level_points  = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
  constraints.min_stop_distance_points = MathMax(constraints.freeze_level_points,
                                                 constraints.stops_level_points);
  constraints.last_refresh        = TimeCurrent();

  bool spec_loaded = (constraints.point_size > 0.0) &&
                     (constraints.tick_size > 0.0) &&
                     (constraints.tick_value > 0.0);

  if(!spec_loaded)
  {
    PrintFormat("Failed to refresh broker constraints for %s (point %.5f tick %.5f value %.2f)",
                symbol,
                constraints.point_size,
                constraints.tick_size,
                constraints.tick_value);
  }

  return spec_loaded;
}

// Immutable, entry-only execution facts; no research or account-state dependency.
struct EntryAdmissionFacts
{
  bool valid;
  bool eligible;
  double bid;
  double ask;
  double point;
  double tick_size;
  double stops_points;
  double freeze_points;
  double risk_price;
  double minimum_price;
};

bool CalculateEntryAdmission(const int direction, const double bid, const double ask,
                             const double sl, const double point, const double tick_size,
                             const double stops_points, const double freeze_points,
                             EntryAdmissionFacts &facts)
{
  ZeroMemory(facts);
  if((direction != 1 && direction != -1) || !MathIsValidNumber(bid) || bid <= 0.0 ||
     !MathIsValidNumber(ask) || ask < bid || ask == EMPTY_VALUE ||
     !MathIsValidNumber(sl) || sl <= 0.0 || sl == EMPTY_VALUE ||
     !MathIsValidNumber(point) || point <= 0.0 || point == EMPTY_VALUE ||
     !MathIsValidNumber(tick_size) || tick_size <= 0.0 || tick_size == EMPTY_VALUE ||
     !MathIsValidNumber(stops_points) || stops_points < 0.0 || stops_points == EMPTY_VALUE ||
     !MathIsValidNumber(freeze_points) || freeze_points < 0.0 || freeze_points == EMPTY_VALUE)
    return false;
  facts.bid = bid;
  facts.ask = ask;
  facts.point = point;
  facts.tick_size = tick_size;
  facts.stops_points = stops_points;
  facts.freeze_points = freeze_points;
  facts.risk_price = direction * ((direction > 0 ? ask : bid) - sl);
  facts.minimum_price = 3.0 * (ask - bid) + MathMax(stops_points, freeze_points) * point + tick_size;
  facts.valid = MathIsValidNumber(facts.risk_price) && MathIsValidNumber(facts.minimum_price) &&
                facts.minimum_price > 0.0 && facts.minimum_price != EMPTY_VALUE;
  facts.eligible = facts.valid && facts.risk_price > 0.0 &&
                   facts.risk_price + tick_size * 0.000001 >= facts.minimum_price;
  return facts.valid;
}

bool CalculateStrictRiskDistancePoints(const double spread_points,
                                       const double point_size,
                                       const double trade_tick_size,
                                       const double stops_level_points,
                                       const double freeze_level_points,
                                       double &minimum_points_out)
{
  minimum_points_out = 0.0;
  if(!MathIsValidNumber(spread_points) || spread_points < 0.0 ||
     !MathIsValidNumber(point_size) || point_size <= 0.0 ||
     !MathIsValidNumber(trade_tick_size) || trade_tick_size <= 0.0 ||
     !MathIsValidNumber(stops_level_points) || stops_level_points < 0.0 ||
     !MathIsValidNumber(freeze_level_points) || freeze_level_points < 0.0)
    return false;

  double trade_tick_points = trade_tick_size / point_size;
  minimum_points_out = spread_points +
                       MathMax(stops_level_points,
                               freeze_level_points) +
                       trade_tick_points;
  return MathIsValidNumber(minimum_points_out) && minimum_points_out > 0.0;
}

#endif // _MICROSERVICES_UTILS_BROKER_CONSTRAINTS_HELPER_MQH_
