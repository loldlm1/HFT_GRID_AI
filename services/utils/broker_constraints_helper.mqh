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

// Calculates the strictest distance required by the broker in points.
double MinBrokerDistancePoints(const SymbolTradingConstraints &constraints)
{
  double freeze_pts = constraints.freeze_level_points;
  double stops_pts  = constraints.stops_level_points;

  if(freeze_pts < 0.0) freeze_pts = 0.0;
  if(stops_pts  < 0.0) stops_pts  = 0.0;

  return MathMax(freeze_pts, stops_pts);
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

// Returns a safe distance in points that respects broker freeze/stops limits.
double EnforceBrokerDistance(const SymbolTradingConstraints &constraints,
                             const double requested_distance_points = 0)
{
  double min_pts = MinBrokerDistancePoints(constraints);

  // If broker did not provide a minimum (0 or negative), derive a safe fallback
  double effective_min = min_pts;
  if(effective_min <= 0.0)
  {
    // Default conservative fallback in points
    double fallback = 10.0;

    // If we have symbol specs, try to derive a sensible fallback from tick/point sizes.
    // tick_size / point_size gives approximate "points per tick" which can be used as a baseline.
    if(constraints.point_size > 0.0 && constraints.tick_size > 0.0)
      fallback = MathMax(10.0, constraints.tick_size / constraints.point_size);
    else if(constraints.point_size > 0.0)
      fallback = MathMax(10.0, 1.0 / constraints.point_size);

    effective_min = fallback;
  }

  if(requested_distance_points < effective_min)
    return effective_min;
  return requested_distance_points;
}

// Simple validation helper. Prints a warning when the requested distance
// violates broker limitations.
bool ValidateDistanceAgainstBrokerLimits(const SymbolTradingConstraints &constraints,
                                         const double distance_points,
                                         const string context_label)
{
  double min_pts = MinBrokerDistancePoints(constraints);
  if(distance_points + 1e-9 < min_pts)
  {
    PrintFormat("[%s] Distance %.2f pts is below broker minimum %.2f pts for %s",
                context_label,
                distance_points,
                min_pts,
                constraints.symbol);
    return false;
  }
  return true;
}

#endif // _MICROSERVICES_UTILS_BROKER_CONSTRAINTS_HELPER_MQH_
