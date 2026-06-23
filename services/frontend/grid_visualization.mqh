#ifndef _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
#define _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_

string g_frontend_tracked_objects[];

double ResolveBreakEvenLinePrice(const SignalParams &signal_params)
{
  if(Grid_BreakEven_Mode == BE_DISABLE)
    return 0.0;

  int total_levels = ArraySize(signal_params.grid_orders);
  if(total_levels <= 0)
    return 0.0;

  for(int i = total_levels - 1; i >= 0; i--)
  {
    GridOrderState state = signal_params.grid_orders[i];
    if(state.break_even_active &&
       state.break_even_price > 0.0 &&
       state.status == GRID_ORDER_ACTIVE)
      return state.break_even_price;
  }

  return 0.0;
}

string FormatTimeframeLabel(const ENUM_TIMEFRAMES tf_value)
{
  string label = EnumToString(tf_value);
  int pos = StringFind(label, "_");
  if(pos >= 0 && pos + 1 < StringLen(label))
    label = StringSubstr(label, pos + 1);
  return label;
}

void DrawGridLevels(const long chart_id,
                    const SignalParams &signal_params,
                    string &tracked_objects[])
{
  if(!signal_params.grid_initialized)
    return;

  string stop_name  = GridSignalObjectName(signal_params, "STOP");
  string tp_name    = GridSignalObjectName(signal_params, "TP");
  string final_name = GridSignalObjectName(signal_params, "TP_FINAL");
  string entry_name = GridSignalObjectName(signal_params, "ENTRY");
  string next_name  = GridSignalObjectName(signal_params, "NEXT");
  string trailing_name = GridSignalObjectName(signal_params, "TP_TRAILING");
  string break_even_name = GridSignalObjectName(signal_params, "BREAK_EVEN");

  int grid_order_level = ArraySize(signal_params.grid_orders)-1;
  if(grid_order_level < 0)
    return;
  GridOrderState level_state = signal_params.grid_orders[grid_order_level];

  double entry_price_line = level_state.entry_reference_price;
  double tp_price         = level_state.take_profit_price;
  double final_price      = level_state.final_take_profit_price;
  double next_level_price = level_state.next_level_price;
  double trailing_price   = level_state.trailing_price;
  double stop_price_line  = 0.0;

  if(IsPandoraSignal(signal_params))
  {
    if(PandoraFirstEntryStageIsObservation(signal_params.pandora_first_entry_stage))
    {
      entry_price_line = signal_params.pandora_observation_anchor_price;
      stop_price_line  = signal_params.pandora_observation_trigger_price;
      tp_price         = signal_params.pandora_observation_tp_price;
    }
    else
    {
      double resolved_sl = 0.0;
      double resolved_tp = 0.0;
      if(PandoraResolveBrokerStops(signal_params, level_state, resolved_sl, resolved_tp))
      {
        stop_price_line = resolved_sl;
        if(resolved_tp > 0.0)
          tp_price = resolved_tp;
      }
    }
    // Hide unused grid visuals to reduce clutter for Pandora.
    final_price      = 0.0;
    next_level_price = 0.0;
    trailing_price   = 0.0;
  }

  string entry_label    = GridSignalLineLabel(signal_params, "ENTRY");
  string tp_label       = GridSignalLineLabel(signal_params, "TP");
  string final_label    = GridSignalLineLabel(signal_params, "FINAL TP");
  string next_label     = GridSignalLineLabel(signal_params, "NEXT");
  string trailing_label = GridSignalLineLabel(signal_params, "TP TRAILING");
  string break_even_label = GridSignalLineLabel(signal_params, "BREAK EVEN");
  string stop_label = GridSignalLineLabel(signal_params, "SL");

  if(IsPandoraSignal(signal_params) &&
     PandoraFirstEntryStageIsObservation(signal_params.pandora_first_entry_stage))
  {
    entry_label = GridSignalLineLabel(signal_params, "OBS ENTRY");
    tp_label = GridSignalLineLabel(signal_params, "TP obs");
    stop_label = GridSignalLineLabel(signal_params,
                                     PandoraFirstEntryObservationTriggerLabel(signal_params) + " entry");
  }
  else if(IsPandoraSignal(signal_params) &&
          level_state.status == GRID_ORDER_TP_TRAILING_ACTIVE)
  {
    stop_label = GridSignalLineLabel(signal_params,
                                    "TRAIL SL step=" +
                                    IntegerToString(signal_params.pandora_trailing_step_index));
  }

  int level_index = level_state.level_index;
  double level_lot_size = level_state.lot_size;
  next_label = StringFormat("%s L%d lot=%.2f",
                            next_label,
                            level_index,
                            level_lot_size);

  UpdateHorizontalLine(chart_id, entry_name, COLOR_PROFIT_NEUTRAL, entry_price_line, entry_label);
  UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, tp_price, tp_label);
  UpdateHorizontalLine(chart_id, final_name, COLOR_PROFIT_POSITIVE, final_price, final_label);
  UpdateHorizontalLine(chart_id, next_name, COLOR_PROFIT_POSITIVE, next_level_price, next_label);

  if(stop_price_line > 0.0)
    UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, stop_price_line, stop_label);
  else
    UpdateHorizontalLine(chart_id, stop_name, COLOR_PROFIT_NEGATIVE, 0.0);

  // Trailing active: swap TP for trailing; Pandora shows the resolved trailing
  // stop on the SL line because broker/local stop handling is SL-based.
  if(level_state.status == GRID_ORDER_TP_TRAILING_ACTIVE)
  {
    UpdateHorizontalLine(chart_id, tp_name, COLOR_PROFIT_POSITIVE, 0.0);
    if(IsPandoraSignal(signal_params))
      UpdateHorizontalLine(chart_id, trailing_name, COLOR_PROFIT_POSITIVE, 0.0);
    else
      UpdateHorizontalLine(chart_id, trailing_name, COLOR_PROFIT_POSITIVE, trailing_price, trailing_label);
  }

  if(Grid_BreakEven_Mode != BE_DISABLE)
  {
    double break_even_price = ResolveBreakEvenLinePrice(signal_params);
    UpdateHorizontalLine(chart_id, break_even_name, COLOR_PROFIT_NEUTRAL, break_even_price, break_even_label, STYLE_DASHDOT);
  }
  else
  {
    UpdateHorizontalLine(chart_id, break_even_name, COLOR_PROFIT_NEUTRAL, 0.0);
  }
}

void BuildSignalSummary(const SignalParams &signal_params,
                        string &summary_lines[],
                        const datetime now_time)
{
  int total_levels = ArraySize(signal_params.grid_orders);
  int active_levels = 0;
  int pending_levels = 0;

  for(int i = 0; i < total_levels; i++)
  {
    GridOrderState level_state = signal_params.grid_orders[i];
    if(level_state.status == GRID_ORDER_ACTIVE)
      active_levels++;
    else if(level_state.status == GRID_ORDER_STOP_TRAILING_ACTIVE ||
            level_state.status == GRID_ORDER_WAITING)
      pending_levels++;
  }

  string direction_label = (signal_params.signal_type == BULLISH) ? "BULL" : "BEAR";
  string context_label = signal_params.strategy_context_label;
  ENUM_TIMEFRAMES tf = signal_params.strategy_timeframe;
  if(tf == PERIOD_CURRENT)
    tf = Strategy_Timeframe;
  string timeframe_label = FormatTimeframeLabel(tf);

  int summary_index = ArraySize(summary_lines);
  ArrayResize(summary_lines, summary_index + 1);

  if(IsPandoraSignal(signal_params))
  {
    string pandora_summary = StringFormat("%s %s %s/%s | act=%d pend=%d trig=%.5f tp=%.5f",
                                          direction_label,
                                          context_label,
                                          PandoraFirstEntryDepthLabel(signal_params.pandora_first_entry_target_depth),
                                          PandoraFirstEntryObservationStageLabel(signal_params),
                                          active_levels,
                                          pending_levels,
                                          signal_params.pandora_observation_trigger_price,
                                          signal_params.pandora_observation_tp_price);
    if(signal_params.pandora_xboost_enabled)
    {
      string execution_label = "watch";
      if(signal_params.pandora_xboost_broker_selected)
        execution_label = "broker";
      else if(signal_params.pandora_xboost_local_only)
        execution_label = "local";

      string display_id = signal_params.pandora_xboost_display_id;
      if(display_id == "")
        display_id = "XB";

      pandora_summary = pandora_summary +
                        StringFormat(" | XB d%d %s %s",
                                     signal_params.pandora_xboost_depth,
                                     display_id,
                                     execution_label);
      if(signal_params.pandora_trailing_step_index > 0)
      {
        pandora_summary = pandora_summary +
                          " ts=" +
                          IntegerToString(signal_params.pandora_trailing_step_index);
      }
    }
    summary_lines[summary_index] = pandora_summary;
  }
  else
  {
    summary_lines[summary_index] = StringFormat("%s %s@%s | act=%d pend=%d tot=%d",
                                                direction_label,
                                                context_label,
                                                timeframe_label,
                                                active_levels,
                                                pending_levels,
                                                total_levels);
  }
}

bool FrontendHasRunningSignals()
{
  if(ArraySize(running_bullish_signals) > 0)
    return true;
  return (ArraySize(running_bearish_signals) > 0);
}

bool FrontendRefreshDue(const datetime now_time)
{
  if(MQLInfoInteger(MQL_TESTER) <= 0)
    return true;
  if(FrontendHasRunningSignals())
    return true;
  if(PandoraHasRuntimeActiveEntities())
    return true;

  static datetime last_tester_bar_time = 0;
  static MarketStatusTypes last_market_status = MARKET_STATUS_ACTIVE;
  static datetime last_market_status_time = 0;
  static datetime last_error_time = 0;

  datetime bar_time = iTime(_Symbol, _Period, 0);
  if(bar_time <= 0)
    bar_time = now_time;

  MarketStatusTypes current_status = MarketStatusGet();
  datetime current_status_time = MarketStatusLastChangeTime();
  datetime current_error_time = MarketStatusErrorLastChangeTime();

  bool first_refresh = (last_tester_bar_time <= 0);
  bool bar_changed = (bar_time != last_tester_bar_time);
  bool status_changed = (current_status != last_market_status ||
                         current_status_time != last_market_status_time ||
                         current_error_time != last_error_time);

  if(!first_refresh && !bar_changed && !status_changed)
    return false;

  last_tester_bar_time = bar_time;
  last_market_status = current_status;
  last_market_status_time = current_status_time;
  last_error_time = current_error_time;
  return true;
}

void RefreshGridVisualization()
{
  long chart_id = ChartID();
  string current_objects[];
  datetime now_time = TimeCurrent();
  string summary_lines[];

  if(!FrontendRefreshDue(now_time))
    return;

  if(Enable_Chart_Levels)
  {
    PandoraDrawVisualization(chart_id, current_objects);

    int bullish_total = ArraySize(running_bullish_signals);
    for(int i = 0; i < bullish_total; i++)
      DrawGridLevels(chart_id, running_bullish_signals[i], current_objects);

    int bearish_total = ArraySize(running_bearish_signals);
    for(int j = 0; j < bearish_total; j++)
      DrawGridLevels(chart_id, running_bearish_signals[j], current_objects);
  }

  if(Enable_Chart_Summary)
  {
    PandoraAppendSummary(summary_lines);
    PandoraXBoostAppendSummaryLines(summary_lines);

    int bullish_total = ArraySize(running_bullish_signals);
    for(int i = 0; i < bullish_total; i++)
      BuildSignalSummary(running_bullish_signals[i], summary_lines, now_time);

    int bearish_total = ArraySize(running_bearish_signals);
    for(int j = 0; j < bearish_total; j++)
      BuildSignalSummary(running_bearish_signals[j], summary_lines, now_time);

  }

  string market_status = MarketStatusToString(MarketStatusGet());
  string status_reason = MarketStatusReason();
  if(FrontendPanelEnabled())
  {
    RenderFrontendPanel(chart_id,
                        now_time,
                        market_status,
                        status_reason,
                        summary_lines,
                        current_objects);
    Comment("");
  }
  else if(FrontendTesterCommentEnabled())
  {
    Comment(BuildTesterSummaryComment(now_time,
                                     market_status,
                                     status_reason,
                                     summary_lines));
  }
  else
  {
    Comment("");
  }

  int previous_total = ArraySize(g_frontend_tracked_objects);
  for(int p = 0; p < previous_total; p++)
  {
    if(!ContainsObjectName(current_objects, g_frontend_tracked_objects[p]))
      ObjectDelete(chart_id, g_frontend_tracked_objects[p]);
  }

  ArrayCopy(g_frontend_tracked_objects, current_objects);
}

void ClearFrontendVisualization()
{
  long chart_id = ChartID();
  int total = ArraySize(g_frontend_tracked_objects);
  for(int i = 0; i < total; i++)
    ObjectDelete(chart_id, g_frontend_tracked_objects[i]);
  ArrayResize(g_frontend_tracked_objects, 0);
  Comment("");
}

#endif // _SERVICES_FRONTEND_GRID_VISUALIZATION_MQH_
