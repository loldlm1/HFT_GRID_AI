//+------------------------------------------------------------------+
//|                       microservices/utils/price_math.mqh        |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_UTILS_PRICE_MATH_MQH_
#define _MICROSERVICES_UTILS_PRICE_MATH_MQH_

struct NextPriceResolution
{
  double next_price;
  string side;
  string clamp_reason;
  string source;

  NextPriceResolution()
  {
    next_price   = 0.0;
    side         = "";
    clamp_reason = "";
    source       = "";
  }
};

void AppendClampReason(string &target,
                       const string reason)
{
  if(reason == "")
    return;
  if(target == "")
  {
    target = reason;
    return;
  }
  target = target + ";" + reason;
}

double ResolveEffectiveTickSize(const double tick_size_candidate,
                                const double point_size_candidate)
{
  if(tick_size_candidate > 0.0)
    return tick_size_candidate;
  if(point_size_candidate > 0.0)
    return point_size_candidate;
  return 0.0001;
}

// Derives the resolved activation price for the next execution level while tracking
// any clamp reasons applied during the calculation.
NextPriceResolution ResolveNextPrice(const double anchor,
                                     const int    level_idx,
                                     const bool   is_bullish,
                                     const double protective_offset_points,
                                     const double stop_level_points,
                                     const double tick_size,
                                     const double spread_points,
                                     double       ask,
                                     double       bid,
                                     const double previous_pending_price)
{
  NextPriceResolution result = NextPriceResolution();
  if(level_idx < 0)
    return result;

  double effective_tick = ResolveEffectiveTickSize(tick_size,
                                                   g_symbol_constraints.point_size);
  double direction_mult = is_bullish ? 1.0 : -1.0;
  result.side = is_bullish ? "ASK" : "BID";
  result.source = "baseline";

  double baseline_price = 0.0;
  if(anchor > 0.0 && stop_level_points > 0.0 && effective_tick > 0.0)
    baseline_price = anchor + direction_mult * stop_level_points * effective_tick;

  double resolved_price = baseline_price;
  double side_price = is_bullish ? ask : bid;
  if(side_price <= 0.0)
    side_price = is_bullish ? bid : ask;

  // Enforce protective offsets to keep stops on the correct side.
  if(side_price > 0.0 && protective_offset_points > 0.0 && effective_tick > 0.0)
  {
    double offset_price = protective_offset_points * effective_tick;
    double required_price = side_price + direction_mult * offset_price;
    if(is_bullish)
    {
      if(resolved_price <= 0.0 || resolved_price < required_price)
      {
        resolved_price = required_price;
        AppendClampReason(result.clamp_reason, "protective");
        result.source = "clamped";
      }
    }
    else
    {
      if(resolved_price <= 0.0 || resolved_price > required_price)
      {
        resolved_price = required_price;
        AppendClampReason(result.clamp_reason, "protective");
        result.source = "clamped";
      }
    }
  }

  // Respect broker-imposed minimum distances.
  double min_distance_points = MinBrokerDistancePoints(g_symbol_constraints);
  if(side_price > 0.0 && min_distance_points > 0.0 && effective_tick > 0.0)
  {
    double required_price = side_price + direction_mult * min_distance_points * effective_tick;
    if(is_bullish)
    {
      if(resolved_price <= 0.0 || resolved_price < required_price)
      {
        resolved_price = required_price;
        AppendClampReason(result.clamp_reason, "broker_stops");
        result.source = "clamped";
      }
    }
    else
    {
      if(resolved_price <= 0.0 || resolved_price > required_price)
      {
        resolved_price = required_price;
        AppendClampReason(result.clamp_reason, "broker_stops");
        result.source = "clamped";
      }
    }
  }

  if(resolved_price <= 0.0)
  {
    if(side_price > 0.0 && effective_tick > 0.0)
    {
      resolved_price = side_price + direction_mult * effective_tick;
      AppendClampReason(result.clamp_reason, "fallback_side");
      result.source = "side_fallback";
    }
    else
    {
      resolved_price = baseline_price;
    }
  }

  // Round to the nearest valid tick respecting the trade direction.
  if(resolved_price > 0.0 && effective_tick > 0.0)
  {
    double ticks = resolved_price / effective_tick;
    double rounded_price = resolved_price;
    if(is_bullish)
      rounded_price = MathCeil(ticks - 1e-9) * effective_tick;
    else
      rounded_price = MathFloor(ticks + 1e-9) * effective_tick;

    if(MathAbs(rounded_price - resolved_price) > 1e-9)
    {
      resolved_price = rounded_price;
      AppendClampReason(result.clamp_reason, "tick_round");
      result.source = "clamped";
    }
  }

  if(previous_pending_price > 0.0 && resolved_price > 0.0)
  {
    double tolerance = effective_tick;
    if(tolerance <= 0.0)
      tolerance = 1e-9;

    if(is_bullish)
    {
      if(resolved_price > previous_pending_price)
      {
        if(resolved_price - previous_pending_price > (tolerance + 1e-9))
          AppendClampReason(result.clamp_reason, "monotonic");
        resolved_price = previous_pending_price;
        result.source = "monotonic";
      }
    }
    else
    {
      if(resolved_price < previous_pending_price)
      {
        if(previous_pending_price - resolved_price > (tolerance + 1e-9))
          AppendClampReason(result.clamp_reason, "monotonic");
        resolved_price = previous_pending_price;
        result.source = "monotonic";
      }
    }
  }

  if(resolved_price <= 0.0)
    result.source = "-";
  result.next_price = resolved_price;
  return result;
}

#endif // _MICROSERVICES_UTILS_PRICE_MATH_MQH_
