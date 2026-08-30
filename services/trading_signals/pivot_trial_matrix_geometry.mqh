//+------------------------------------------------------------------+
//|                  trading_signals/pivot_trial_matrix_geometry    |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_GEOMETRY_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_GEOMETRY_MQH_

bool PivotTrialQuoteValid(const MqlTick &tick)
{
  return MathIsValidNumber(tick.bid) &&
         MathIsValidNumber(tick.ask) &&
         tick.bid > 0.0 &&
         tick.ask >= tick.bid;
}

double PivotTrialEntryPriceFromTick(const SignalTypes direction,
                                    const MqlTick &tick)
{
  if(direction == BULLISH)
    return tick.ask;
  if(direction == BEARISH)
    return tick.bid;
  return 0.0;
}

double PivotTrialExitPriceFromTick(const SignalTypes direction,
                                   const MqlTick &tick)
{
  if(direction == BULLISH)
    return tick.bid;
  if(direction == BEARISH)
    return tick.ask;
  return 0.0;
}

PivotTrialQuoteSides PivotTrialEntryQuoteSide(const SignalTypes direction)
{
  if(direction == BULLISH)
    return PIVOT_TRIAL_QUOTE_SIDE_ASK;
  if(direction == BEARISH)
    return PIVOT_TRIAL_QUOTE_SIDE_BID;
  return PIVOT_TRIAL_QUOTE_SIDE_NONE;
}

PivotTrialQuoteSides PivotTrialExitQuoteSide(const SignalTypes direction)
{
  if(direction == BULLISH)
    return PIVOT_TRIAL_QUOTE_SIDE_BID;
  if(direction == BEARISH)
    return PIVOT_TRIAL_QUOTE_SIDE_ASK;
  return PIVOT_TRIAL_QUOTE_SIDE_NONE;
}

bool PivotTrialPriceDistancePoints(const double first_price,
                                   const double second_price,
                                   const double point_size,
                                   double &distance_points_out)
{
  distance_points_out = 0.0;
  if(!MathIsValidNumber(first_price) || first_price <= 0.0 ||
     !MathIsValidNumber(second_price) || second_price <= 0.0 ||
     !MathIsValidNumber(point_size) || point_size <= 0.0)
    return false;
  distance_points_out = MathAbs(first_price - second_price) / point_size;
  return MathIsValidNumber(distance_points_out);
}

bool NormalizePivotTrialRiskOutward(const double requested_distance_price,
                                    const double trade_tick_size,
                                    long &risk_ticks_out,
                                    double &normalized_distance_price_out)
{
  risk_ticks_out = 0;
  normalized_distance_price_out = 0.0;
  if(!MathIsValidNumber(requested_distance_price) ||
     requested_distance_price <= 0.0 ||
     !MathIsValidNumber(trade_tick_size) || trade_tick_size <= 0.0)
    return false;

  double requested_ticks = requested_distance_price / trade_tick_size;
  if(!MathIsValidNumber(requested_ticks) || requested_ticks <= 0.0)
    return false;
  long risk_ticks = (long)MathCeil(requested_ticks - 1e-12);
  if(risk_ticks <= 0)
    risk_ticks = 1;
  double normalized_distance = (double)risk_ticks * trade_tick_size;
  if(normalized_distance < requested_distance_price)
  {
    risk_ticks++;
    normalized_distance = (double)risk_ticks * trade_tick_size;
  }
  if(!MathIsValidNumber(normalized_distance) ||
     normalized_distance < requested_distance_price)
    return false;
  risk_ticks_out = risk_ticks;
  normalized_distance_price_out = normalized_distance;
  return true;
}

bool BuildPivotTrialStopAndTakeProfit(const SignalTypes direction,
                                      const double entry_price,
                                      const long normalized_risk_ticks,
                                      const double trade_tick_size,
                                      const int tp_r_multiple,
                                      double &stop_loss_out,
                                      double &take_profit_out)
{
  stop_loss_out = 0.0;
  take_profit_out = 0.0;
  if((direction != BULLISH && direction != BEARISH) ||
     !MathIsValidNumber(entry_price) || entry_price <= 0.0 ||
     normalized_risk_ticks <= 0 ||
     !MathIsValidNumber(trade_tick_size) || trade_tick_size <= 0.0 ||
     !PivotTrialTpMultipleSupported(tp_r_multiple))
    return false;

  double normalized_risk = (double)normalized_risk_ticks * trade_tick_size;
  double normalized_reward = normalized_risk * (double)tp_r_multiple;
  if(direction == BULLISH)
  {
    stop_loss_out = entry_price - normalized_risk;
    take_profit_out = entry_price + normalized_reward;
  }
  else
  {
    stop_loss_out = entry_price + normalized_risk;
    take_profit_out = entry_price - normalized_reward;
  }
  return MathIsValidNumber(stop_loss_out) && stop_loss_out > 0.0 &&
         MathIsValidNumber(take_profit_out) && take_profit_out > 0.0;
}

bool PivotTrialExactIntegerR(const SignalTypes direction,
                             const double entry_price,
                             const double stop_loss_price,
                             const double take_profit_price,
                             const int tp_r_multiple,
                             const double trade_tick_size)
{
  if((direction != BULLISH && direction != BEARISH) ||
     !PivotTrialTpMultipleSupported(tp_r_multiple) ||
     !MathIsValidNumber(trade_tick_size) || trade_tick_size <= 0.0)
    return false;
  double risk_price = direction == BULLISH
                      ? entry_price - stop_loss_price
                      : stop_loss_price - entry_price;
  double reward_price = direction == BULLISH
                        ? take_profit_price - entry_price
                        : entry_price - take_profit_price;
  if(risk_price <= 0.0 || reward_price <= 0.0)
    return false;
  double tolerance = trade_tick_size * 1e-7;
  return MathAbs(reward_price - risk_price * (double)tp_r_multiple) <=
         tolerance;
}

bool PivotTrialNextOutwardBoundary(const SignalTypes direction,
                                   const PivotLevelIds origin_level,
                                   const PivotPriceLadder &levels,
                                   bool &boundary_available_out,
                                   double &boundary_price_out)
{
  boundary_available_out = false;
  boundary_price_out = 0.0;
  PivotLevelIds boundary_level = PIVOT_LEVEL_PP;
  if(direction == BULLISH)
  {
    switch(origin_level)
    {
      case PIVOT_LEVEL_PP: boundary_level = PIVOT_LEVEL_S1; break;
      case PIVOT_LEVEL_S1: boundary_level = PIVOT_LEVEL_S2; break;
      case PIVOT_LEVEL_S2: boundary_level = PIVOT_LEVEL_S3; break;
      case PIVOT_LEVEL_S3:
      {
        double s2 = 0.0;
        double s3 = 0.0;
        if(!PivotTradePrice(levels, PIVOT_LEVEL_S2, s2) ||
           !PivotTradePrice(levels, PIVOT_LEVEL_S3, s3))
          return false;
        boundary_price_out = s3 - (s2 - s3);
        double origin_price = 0.0;
        boundary_available_out =
          PivotTradePrice(levels, origin_level, origin_price) &&
          boundary_price_out > 0.0 && boundary_price_out < origin_price;
        return boundary_available_out;
      }
      default: return false;
    }
  }
  else if(direction == BEARISH)
  {
    switch(origin_level)
    {
      case PIVOT_LEVEL_PP: boundary_level = PIVOT_LEVEL_R1; break;
      case PIVOT_LEVEL_R1: boundary_level = PIVOT_LEVEL_R2; break;
      case PIVOT_LEVEL_R2: boundary_level = PIVOT_LEVEL_R3; break;
      case PIVOT_LEVEL_R3:
      {
        double r2 = 0.0;
        double r3 = 0.0;
        if(!PivotTradePrice(levels, PIVOT_LEVEL_R2, r2) ||
           !PivotTradePrice(levels, PIVOT_LEVEL_R3, r3))
          return false;
        boundary_price_out = r3 + (r3 - r2);
        double origin_price = 0.0;
        boundary_available_out =
          PivotTradePrice(levels, origin_level, origin_price) &&
          boundary_price_out > 0.0 && boundary_price_out > origin_price;
        return boundary_available_out;
      }
      default: return false;
    }
  }
  else
  {
    return false;
  }
  if(!PivotTradePrice(levels, boundary_level, boundary_price_out))
    return false;
  double origin_price = 0.0;
  if(!PivotTradePrice(levels, origin_level, origin_price) ||
     (direction == BULLISH && boundary_price_out >= origin_price) ||
     (direction == BEARISH && boundary_price_out <= origin_price))
    return false;
  boundary_available_out = true;
  return true;
}

bool PivotTrialMidpointPrice(const SignalTypes direction,
                             const double pivot_price,
                             const double boundary_price,
                             double &midpoint_price_out)
{
  midpoint_price_out = 0.0;
  if((direction != BULLISH && direction != BEARISH) ||
     !MathIsValidNumber(pivot_price) || pivot_price <= 0.0 ||
     !MathIsValidNumber(boundary_price) || boundary_price <= 0.0)
    return false;
  if((direction == BULLISH && boundary_price >= pivot_price) ||
     (direction == BEARISH && boundary_price <= pivot_price))
    return false;
  midpoint_price_out = pivot_price + 0.5 * (boundary_price - pivot_price);
  return MathIsValidNumber(midpoint_price_out) && midpoint_price_out > 0.0;
}

bool PivotTrialMidpointTouched(const SignalTypes direction,
                               const double bid,
                               const double midpoint_price)
{
  if(!MathIsValidNumber(bid) || bid <= 0.0 ||
     !MathIsValidNumber(midpoint_price) || midpoint_price <= 0.0)
    return false;
  if(direction == BULLISH)
    return bid <= midpoint_price;
  if(direction == BEARISH)
    return bid >= midpoint_price;
  return false;
}

ulong PivotTrialStableHash(const string value)
{
  ulong hash = 1469598103934665603;
  for(int i = 0; i < StringLen(value); i++)
  {
    hash ^= (ulong)StringGetCharacter(value, i);
    hash *= 1099511628211;
  }
  return hash;
}

string PivotTrialGeometryEquivalenceId(const string origin_id,
                                       const SignalTypes direction,
                                       const double entry_price,
                                       const double stop_loss_price,
                                       const double take_profit_price)
{
  if(origin_id == "" ||
     (direction != BULLISH && direction != BEARISH) ||
     entry_price <= 0.0 || stop_loss_price <= 0.0 ||
     take_profit_price <= 0.0)
    return "";
  string payload = origin_id + "|" + IntegerToString((int)direction) + "|" +
                   DoubleToString(entry_price, 12) + "|" +
                   DoubleToString(stop_loss_price, 12) + "|" +
                   DoubleToString(take_profit_price, 12);
  return "geom_" + StringFormat("%I64u", PivotTrialStableHash(payload));
}

bool PivotTrialGeometryEquivalent(const PivotTrialGeometry &left,
                                  const PivotTrialGeometry &right)
{
  if(!left.valid || !right.valid || left.direction != right.direction)
    return false;
  double comparison_tick = MathMin(left.trade_tick_size,
                                   right.trade_tick_size);
  if(comparison_tick <= 0.0)
    return false;
  double tolerance = comparison_tick * 1e-7;
  return MathAbs(left.entry_price - right.entry_price) <= tolerance &&
         MathAbs(left.stop_loss_price - right.stop_loss_price) <= tolerance &&
         MathAbs(left.take_profit_price - right.take_profit_price) <= tolerance;
}

bool BuildPivotTrialGeometry(const string origin_id,
                             const SignalTypes direction,
                             const MqlTick &tick,
                             const double requested_risk_distance_price,
                             const int tp_r_multiple,
                             const double point_size,
                             const double trade_tick_size,
                             const double stops_level_points,
                             const double freeze_level_points,
                             PivotTrialGeometry &geometry_out)
{
  geometry_out.Reset();
  geometry_out.direction = direction;
  geometry_out.entry_bid = tick.bid;
  geometry_out.entry_ask = tick.ask;
  geometry_out.point_size = point_size;
  geometry_out.trade_tick_size = trade_tick_size;
  geometry_out.stops_level_points = stops_level_points;
  geometry_out.freeze_level_points = freeze_level_points;

  if(origin_id == "" ||
     (direction != BULLISH && direction != BEARISH) ||
     !PivotTrialQuoteValid(tick) ||
     !MathIsValidNumber(point_size) || point_size <= 0.0 ||
     !MathIsValidNumber(trade_tick_size) || trade_tick_size <= 0.0 ||
     !MathIsValidNumber(stops_level_points) || stops_level_points < 0.0 ||
     !MathIsValidNumber(freeze_level_points) || freeze_level_points < 0.0)
  {
    geometry_out.invalid_reason = "TRIAL_GEOMETRY_INPUT_INVALID";
    return false;
  }

  geometry_out.entry_price = PivotTrialEntryPriceFromTick(direction, tick);
  geometry_out.entry_quote_side = PivotTrialEntryQuoteSide(direction);
  geometry_out.exit_quote_side = PivotTrialExitQuoteSide(direction);
  geometry_out.spread_points = (tick.ask - tick.bid) / point_size;
  geometry_out.requested_risk_distance_price = requested_risk_distance_price;
  geometry_out.requested_risk_distance_points =
    requested_risk_distance_price / point_size;
  if(!NormalizePivotTrialRiskOutward(requested_risk_distance_price,
                                    trade_tick_size,
                                    geometry_out.normalized_risk_ticks,
                                    geometry_out.normalized_risk_distance_price))
  {
    geometry_out.invalid_reason = "RISK_TICK_NORMALIZATION_FAILED";
    return false;
  }
  geometry_out.normalized_risk_distance_points =
    geometry_out.normalized_risk_distance_price / point_size;
  if(!BuildPivotTrialStopAndTakeProfit(direction,
                                      geometry_out.entry_price,
                                      geometry_out.normalized_risk_ticks,
                                      trade_tick_size,
                                      tp_r_multiple,
                                      geometry_out.stop_loss_price,
                                      geometry_out.take_profit_price) ||
     !PivotTrialExactIntegerR(direction,
                             geometry_out.entry_price,
                             geometry_out.stop_loss_price,
                             geometry_out.take_profit_price,
                             tp_r_multiple,
                             trade_tick_size))
  {
    geometry_out.invalid_reason = "EXACT_INTEGER_R_GEOMETRY_FAILED";
    return false;
  }
  if(!CalculateStrictRiskDistancePoints(geometry_out.spread_points,
                                        point_size,
                                        trade_tick_size,
                                        stops_level_points,
                                        freeze_level_points,
                                        geometry_out.minimum_risk_distance_points))
  {
    geometry_out.invalid_reason = "MINIMUM_RISK_DISTANCE_FAILED";
    return false;
  }
  geometry_out.distance_eligible =
    geometry_out.normalized_risk_distance_points + 1e-7 >=
    geometry_out.minimum_risk_distance_points;
  geometry_out.geometry_equivalence_id =
    PivotTrialGeometryEquivalenceId(origin_id,
                                    direction,
                                    geometry_out.entry_price,
                                    geometry_out.stop_loss_price,
                                    geometry_out.take_profit_price);
  if(geometry_out.geometry_equivalence_id == "")
  {
    geometry_out.invalid_reason = "GEOMETRY_EQUIVALENCE_ID_FAILED";
    return false;
  }
  geometry_out.valid = true;
  geometry_out.invalid_reason = "";
  return true;
}

bool BuildPivotTrialGeometryAtStop(const string origin_id,
                                   const SignalTypes direction,
                                   const MqlTick &tick,
                                   const double stop_loss_price,
                                   const int tp_r_multiple,
                                   const double point_size,
                                   const double trade_tick_size,
                                   const double stops_level_points,
                                   const double freeze_level_points,
                                   const bool allow_outward_normalization,
                                   PivotTrialGeometry &geometry_out)
{
  geometry_out.Reset();
  double entry_price = PivotTrialEntryPriceFromTick(direction, tick);
  if(entry_price <= 0.0 || !MathIsValidNumber(stop_loss_price) ||
     stop_loss_price <= 0.0 ||
     (direction == BULLISH && stop_loss_price >= entry_price) ||
     (direction == BEARISH && stop_loss_price <= entry_price))
  {
    geometry_out.invalid_reason = "STRUCTURAL_STOP_WRONG_SIDE";
    return false;
  }
  double requested_risk = MathAbs(entry_price - stop_loss_price);
  if(!BuildPivotTrialGeometry(origin_id,
                              direction,
                              tick,
                              requested_risk,
                              tp_r_multiple,
                              point_size,
                              trade_tick_size,
                              stops_level_points,
                              freeze_level_points,
                              geometry_out))
    return false;
  double tolerance = trade_tick_size * 1e-7;
  if(MathAbs(geometry_out.stop_loss_price - stop_loss_price) > tolerance &&
     !allow_outward_normalization)
  {
    geometry_out.Reset();
    geometry_out.invalid_reason = "STRUCTURAL_STOP_NOT_TICK_ALIGNED";
    return false;
  }
  if(allow_outward_normalization &&
     ((direction == BULLISH && geometry_out.stop_loss_price > stop_loss_price + tolerance) ||
      (direction == BEARISH && geometry_out.stop_loss_price < stop_loss_price - tolerance)))
  {
    geometry_out.Reset();
    geometry_out.invalid_reason = "STOP_NORMALIZATION_NOT_OUTWARD";
    return false;
  }
  if(!allow_outward_normalization)
    geometry_out.stop_loss_price = stop_loss_price;
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_TRIAL_MATRIX_GEOMETRY_MQH_
