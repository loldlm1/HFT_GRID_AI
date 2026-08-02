//+------------------------------------------------------------------+
//|                   pivot_hft_risk_geometry.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RISK_GEOMETRY_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RISK_GEOMETRY_MQH_

bool PivotHftValidateRiskGeometryInputs(string &reason)
{
  reason = "";

  if(Pivot_HFT_Local_SL_Bands_Width_Percent <= 0.0)
  {
    reason = "local_sl_bands_percent_must_be_positive";
    return false;
  }
  if(Pivot_HFT_TP_Step_SL_Ratio <= 0.0)
  {
    reason = "tp_step_sl_ratio_must_be_positive";
    return false;
  }
  if(Pivot_HFT_Fixed_TP_SL_Ratio < 0.0)
  {
    reason = "fixed_tp_sl_ratio_cannot_be_negative";
    return false;
  }
  return true;
}

bool PivotHftResolveRiskGeometry(PivotHftRiskGeometry &geometry,
                                 string &reason)
{
  reason = "";
  geometry.bands_source_bar = g_pivot_hft_bands_bar;
  geometry.bands_upper = g_pivot_hft_bands_upper;
  geometry.bands_lower = g_pivot_hft_bands_lower;
  geometry.band_width_points = 0.0;
  geometry.initial_sl_points = 0.0;
  geometry.trailing_step_points = 0.0;
  geometry.fixed_tp_points = 0.0;
  geometry.valid = false;

  if(!PivotHftValidateRiskGeometryInputs(reason))
    return false;

  double point_size = PivotHftPointSize();
  if(point_size <= 0.0)
  {
    reason = "invalid_symbol_point_size";
    return false;
  }
  double tick_size = PivotHftTickSize();
  if(tick_size <= 0.0)
  {
    reason = "invalid_symbol_tick_size";
    return false;
  }
  double minimum_distance_points = tick_size / point_size;

  if(geometry.bands_upper > geometry.bands_lower &&
     geometry.bands_lower > 0.0)
  {
    geometry.band_width_points =
      (geometry.bands_upper - geometry.bands_lower) / point_size;
  }

  if(geometry.bands_source_bar <= 0 ||
     geometry.band_width_points <= 0.0)
  {
    reason = "bands_width_not_ready";
    return false;
  }
  geometry.initial_sl_points =
    geometry.band_width_points *
    Pivot_HFT_Local_SL_Bands_Width_Percent / 100.0;

  if(geometry.initial_sl_points < minimum_distance_points)
  {
    reason = "resolved_local_sl_below_one_tick";
    return false;
  }

  geometry.trailing_step_points =
    geometry.initial_sl_points * Pivot_HFT_TP_Step_SL_Ratio;

  if(geometry.trailing_step_points < minimum_distance_points)
  {
    reason = "resolved_tp_step_below_one_tick";
    return false;
  }

  if(Pivot_HFT_Fixed_TP_SL_Ratio > 0.0)
  {
    geometry.fixed_tp_points =
      geometry.initial_sl_points * Pivot_HFT_Fixed_TP_SL_Ratio;
    if(geometry.fixed_tp_points < minimum_distance_points)
    {
      reason = "resolved_fixed_tp_below_one_tick";
      return false;
    }
  }

  geometry.valid = true;
  return true;
}

bool PivotHftResolveEntrySafetySnapshot(
  const double requested_sl_points,
  const bool broker_constraints_ready,
  PivotHftEntrySafetySnapshot &snapshot)
{
  snapshot = PivotHftEntrySafetySnapshot();
  snapshot.evaluated_at = TimeCurrent();
  snapshot.requested_sl_points = requested_sl_points;
  snapshot.spread_points = g_points_spread;
  snapshot.stops_level_points = g_symbol_constraints.stops_level_points;
  snapshot.freeze_level_points = g_symbol_constraints.freeze_level_points;
  snapshot.point_size = g_symbol_constraints.point_size;
  snapshot.tick_size = g_symbol_constraints.tick_size;
  snapshot.blocked = true;

  if(!broker_constraints_ready)
  {
    snapshot.reason = "broker_constraints_refresh_failed";
    return false;
  }
  if(!MathIsValidNumber(snapshot.point_size) || snapshot.point_size <= 0.0)
  {
    snapshot.reason = "invalid_symbol_point_size";
    return false;
  }
  if(!MathIsValidNumber(snapshot.tick_size) || snapshot.tick_size <= 0.0)
  {
    snapshot.reason = "invalid_symbol_tick_size";
    return false;
  }
  if(!MathIsValidNumber(snapshot.spread_points) || snapshot.spread_points < 0.0)
  {
    snapshot.reason = "invalid_current_spread";
    return false;
  }
  if(!MathIsValidNumber(requested_sl_points) || requested_sl_points <= 0.0)
  {
    snapshot.reason = "invalid_requested_local_sl";
    return false;
  }

  snapshot.broker_floor_points = EffectiveBrokerDistancePoints(
    g_symbol_constraints,
    0.0,
    1.0);
  if(!MathIsValidNumber(snapshot.broker_floor_points) ||
     snapshot.broker_floor_points <= 0.0)
  {
    snapshot.reason = "invalid_broker_distance_floor";
    return false;
  }

  snapshot.required_initial_sl_points =
    snapshot.spread_points + snapshot.broker_floor_points;
  if(!MathIsValidNumber(snapshot.required_initial_sl_points) ||
     snapshot.required_initial_sl_points <= 0.0)
  {
    snapshot.reason = "invalid_required_local_sl";
    return false;
  }

  snapshot.valid = true;
  if(requested_sl_points + 1e-9 < snapshot.required_initial_sl_points)
  {
    snapshot.reason = "requested_sl_below_spread_and_broker_floor";
    return false;
  }

  snapshot.blocked = false;
  snapshot.reason = "ok";
  return true;
}

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RISK_GEOMETRY_MQH_
