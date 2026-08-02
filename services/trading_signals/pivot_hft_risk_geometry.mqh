//+------------------------------------------------------------------+
//|                   pivot_hft_risk_geometry.mqh                   |
//+------------------------------------------------------------------+
#ifndef _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RISK_GEOMETRY_MQH_
#define _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RISK_GEOMETRY_MQH_

bool PivotHftValidateRiskGeometryInputs(string &reason)
{
  reason = "";

  if(Pivot_HFT_Local_SL_Mode == PIVOT_HFT_LOCAL_SL_POINTS)
  {
    if(Pivot_HFT_Local_SL_Points <= 0.0)
      reason = "local_sl_points_must_be_positive";
  }
  else if(Pivot_HFT_Local_SL_Mode ==
          PIVOT_HFT_LOCAL_SL_BANDS_WIDTH_PERCENT)
  {
    if(Pivot_HFT_Local_SL_Bands_Width_Percent <= 0.0)
      reason = "local_sl_bands_percent_must_be_positive";
  }
  else
    reason = "invalid_local_sl_mode";

  if(reason != "")
    return false;
  if(Pivot_HFT_TP_Step_SL_Ratio < 0.0)
  {
    reason = "tp_step_sl_ratio_cannot_be_negative";
    return false;
  }
  if(Pivot_HFT_TP_Step_SL_Ratio == 0.0 &&
     Pivot_HFT_TP_Step_Points <= 0.0)
  {
    reason = "tp_step_points_must_be_positive";
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
  geometry.local_sl_mode = Pivot_HFT_Local_SL_Mode;
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

  if(geometry.local_sl_mode == PIVOT_HFT_LOCAL_SL_POINTS)
    geometry.initial_sl_points = Pivot_HFT_Local_SL_Points;
  else
  {
    if(geometry.bands_source_bar <= 0 ||
       geometry.band_width_points <= 0.0)
    {
      reason = "bands_width_not_ready";
      return false;
    }
    geometry.initial_sl_points =
      geometry.band_width_points *
      Pivot_HFT_Local_SL_Bands_Width_Percent / 100.0;
  }

  if(geometry.initial_sl_points < minimum_distance_points)
  {
    reason = "resolved_local_sl_below_one_tick";
    return false;
  }

  if(Pivot_HFT_TP_Step_SL_Ratio > 0.0)
  {
    geometry.trailing_step_points =
      geometry.initial_sl_points * Pivot_HFT_TP_Step_SL_Ratio;
  }
  else
    geometry.trailing_step_points = Pivot_HFT_TP_Step_Points;

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

#endif // _SERVICES_TRADING_SIGNALS_PIVOT_HFT_RISK_GEOMETRY_MQH_
