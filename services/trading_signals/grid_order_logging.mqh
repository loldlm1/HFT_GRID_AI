//+------------------------------------------------------------------+
//|                   microservices/trading_signals/... logging      |
//+------------------------------------------------------------------+
#ifndef _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
#define _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_

#include "grid_order_helpers.mqh"

const string QUERY_DEBUG_FILENAME = "query_debug.txt";
bool g_query_debug_session_header_logged = false;
string g_query_debug_state_keys[];
string g_query_debug_state_messages[];

string GridBoolToken(const bool value)
{
  return value ? "true" : "false";
}

string GridSessionModeToken(const SessionTimeFilterModes mode)
{
  switch(mode)
  {
    case SESSION_FILTER_ALLOW_RUN:
      return "ALLOW_RUN";
    case SESSION_FILTER_FORCE_CLOSE:
      return "FORCE_CLOSE";
  }
  return "OFF";
}

void ResetQueryDebugLogSession()
{
  g_query_debug_session_header_logged = false;
  ArrayResize(g_query_debug_state_keys, 0);
  ArrayResize(g_query_debug_state_messages, 0);
}

void GridAppendRawQueryDebugLine(const string line)
{
  AppendFileLog(QUERY_DEBUG_FILENAME, line);
}

void GridAppendTimestampedQueryDebug(const string label,
                                     const string message)
{
  AppendTimestampedLog(QUERY_DEBUG_FILENAME, label, message);
}

string GridQueryDebugSignalKey(const SignalParams &signal_params)
{
  if(signal_params.grid_sequence_id != "")
    return signal_params.grid_sequence_id;

  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string time_token = TimeToString(signal_params.entry_time, TIME_DATE|TIME_SECONDS);
  return direction + "|" + time_token;
}

int GridFindQueryDebugStateIndex(const string state_key)
{
  int total = ArraySize(g_query_debug_state_keys);
  for(int i = 0; i < total; i++)
  {
    if(g_query_debug_state_keys[i] == state_key)
      return i;
  }
  return -1;
}

bool GridShouldLogChangedState(const string state_key,
                               const string message)
{
  int index = GridFindQueryDebugStateIndex(state_key);
  if(index < 0)
  {
    int total = ArraySize(g_query_debug_state_keys);
    ArrayResize(g_query_debug_state_keys, total + 1);
    ArrayResize(g_query_debug_state_messages, total + 1);
    g_query_debug_state_keys[total] = state_key;
    g_query_debug_state_messages[total] = message;
    return true;
  }

  if(g_query_debug_state_messages[index] == message)
    return false;

  g_query_debug_state_messages[index] = message;
  return true;
}

void EnsureQueryDebugSessionHeaderLogged()
{
  if(!Enable_File_Logs || g_query_debug_session_header_logged)
    return;

  g_query_debug_session_header_logged = true;
  GridAppendRawQueryDebugLine("");

  double point_size = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  if(point_size <= 0.0)
    point_size = 0.0001;

  GridAppendTimestampedQueryDebug("QUERY_DEBUG_SESSION",
                                  StringFormat("symbol=%s|period=%s|point=%.5f|digits=%d|spread_pts=%.1f|spread_raw=%.5f|max_spread=%.1f",
                                               _Symbol,
                                               EnumToString(_Period),
                                               point_size,
                                               Digits(),
                                               g_points_spread,
                                               g_local_spread,
                                               Max_Spread));

  GridAppendTimestampedQueryDebug("INPUTS_ACCOUNT",
                                  StringFormat("magic=%d|min_range=%.1f|account_size=%.1f|protection=%s|drawdown_type=%s|drawdown=%.1f|close_guard_tf=%s",
                                               Custom_Magic,
                                               Min_Range_Points,
                                               Account_Size,
                                               EnumToString(Protection_Risk_Mode),
                                               EnumToString(Protection_Risk_Drawdown_Type),
                                               Protection_Risk_Drawdown_Value,
                                               EnumToString(Market_Close_Guard_Timeframe)));

  GridAppendTimestampedQueryDebug("INPUTS_SESSION",
                                  StringFormat("asia=%s@%s|london=%s@%s|newyork=%s@%s|dst=%s|dst_manual=%d",
                                               GridSessionModeToken(Session_Asia_Filter_Mode),
                                               Session_Asia_Filter_Time_Range,
                                               GridSessionModeToken(Session_London_Filter_Mode),
                                               Session_London_Filter_Time_Range,
                                               GridSessionModeToken(Session_NewYork_Filter_Mode),
                                               Session_NewYork_Filter_Time_Range,
                                               SessionTimeFilterDstStatusSummary(),
                                               Session_Time_Dst_Manual_Offset_Minutes));

  GridAppendTimestampedQueryDebug("INPUTS_STRATEGY",
                                  StringFormat("tf=%s|stoch_period=%d|trigger=%s|touch=%s|direction=%s|concurrency=%s",
                                               EnumToString(Strategy_Timeframe),
                                               Stoch_Structure_Period_Type,
                                               EnumToString(Structure_Trigger_Entry),
                                               EnumToString(Structure_Touch_Policy),
                                               EnumToString(Strategy_Direction_Mode),
                                               EnumToString(Signal_Concurrency_Mode)));

  GridAppendTimestampedQueryDebug("INPUTS_FIB",
                                  StringFormat("levels=%s",
                                               Structure_Fibonacci_Levels));

  GridAppendTimestampedQueryDebug("INPUTS_GRID",
                                  StringFormat("base=%s|points_range=%.1f|grid_mult=%.2f|level_start=%d|stop_limit=%d|lot_type=%s|lot_size=%.2f|lot_mult=%.2f|tp_percent=%.1f",
                                               EnumToString(Base_Strategy_Type),
                                               Points_Range_Setup,
                                               Grid_Exponential_Multiplier,
                                               Grid_Level_Position_Start,
                                               Grid_Level_Stop_Limit,
                                               EnumToString(Lot_Type),
                                               Lot_Strategy_Size,
                                               Lot_Multiplier,
                                               TP_Percent));

  GridAppendTimestampedQueryDebug("INPUTS_FILTERS",
                                  StringFormat("candle=%s@%s[shift=%d,depth=%d]|sr_chain=%s[count=%d,range=%.1f]|trailing=%s[tp_close=%.1f]|compound=%s|fresh=%s",
                                               EnumToString(Candle_Strategy_Type),
                                               EnumToString(Candle_Timeframe),
                                               Candle_Strategy_Shift,
                                               Candle_Strategy_Depth,
                                               GridBoolToken(Support_Resistance_Retest_Chain_Enabled),
                                               Support_Resistance_Retest_Chain_Count,
                                               Support_Resistance_Retest_Chain_Range_Percent,
                                               EnumToString(Trailing_Structure_Mode),
                                               Trailing_TP_Close_Percent,
                                               EnumToString(Base_Structure_Compound_Filter),
                                               GridBoolToken(Base_Fresh_Structure_Time)));
}

void GridAppendQueryDebugLog(const string label,
                             const string message)
{
  if(!Enable_File_Logs)
    return;

  EnsureQueryDebugSessionHeaderLogged();
  GridAppendTimestampedQueryDebug(label, message);
}

void GridAppendQueryDebugChangedLog(const string label,
                                    const string state_key,
                                    const string message)
{
  if(!Enable_File_Logs)
    return;

  EnsureQueryDebugSessionHeaderLogged();
  if(!GridShouldLogChangedState(label + "|" + state_key, message))
    return;

  GridAppendTimestampedQueryDebug(label, message);
}

string GridFormatDoubleOrToken(const bool valid,
                               const double value,
                               const int digits)
{
  if(!valid)
    return "n/a";
  return DoubleToString(value, digits);
}

string GridStructureTypeToken(const OscillatorStructureTypes structure_type)
{
  switch(structure_type)
  {
    case OSCILLATOR_STRUCTURE_HH:
      return "HH";
    case OSCILLATOR_STRUCTURE_HL:
      return "HL";
    case OSCILLATOR_STRUCTURE_LH:
      return "LH";
    case OSCILLATOR_STRUCTURE_LL:
      return "LL";
    default:
      return "EQ";
  }
}

string GridComposeStructureSequence(const OscillatorStructureTypes first,
                                    const OscillatorStructureTypes second,
                                    const OscillatorStructureTypes third,
                                    const OscillatorStructureTypes fourth)
{
  return StringFormat("%s,%s,%s,%s",
                      GridStructureTypeToken(first),
                      GridStructureTypeToken(second),
                      GridStructureTypeToken(third),
                      GridStructureTypeToken(fourth));
}

string GridResolveCurrentSignalStructureSequence(const SignalParams &signal_params)
{
  StochasticMarketStructure structure;
  if(!ResolveSignalStructureSnapshot(signal_params, structure))
    return "n/a";

  return GridComposeStructureSequence(structure.first_structure_type,
                                      structure.second_structure_type,
                                      structure.third_structure_type,
                                      structure.fourth_structure_type);
}

bool GridResolveRequiredCompoundStructureSequence(const SignalParams &signal_params,
                                                  string &required_sequence_out)
{
  required_sequence_out = "";

  StrategyStructureLayerContext ctx = BuildStructureLayerForContext(signal_params.strategy_context);
  if(!ctx.enabled)
    return false;
  if(!StructureCompoundFilterIsEnabled(ctx.structure_compound_filter))
    return false;

  OscillatorStructureTypes expected_first = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_second = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_third = OSCILLATOR_STRUCTURE_EQ;
  OscillatorStructureTypes expected_fourth = OSCILLATOR_STRUCTURE_EQ;
  if(!ResolveStructureCompoundCanonicalTemplate(ctx.structure_compound_filter,
                                                expected_first,
                                                expected_second,
                                                expected_third,
                                                expected_fourth))
    return false;

  required_sequence_out = GridComposeStructureSequence(expected_first,
                                                       expected_second,
                                                       expected_third,
                                                       expected_fourth);
  return true;
}

string GridResolveStructureAuditSummary(const SignalParams &signal_params)
{
  string current_sequence = GridResolveCurrentSignalStructureSequence(signal_params);
  string required_sequence = "";
  if(!GridResolveRequiredCompoundStructureSequence(signal_params, required_sequence))
    return current_sequence;

  return current_sequence + "==" + required_sequence;
}

bool GridShouldPrintTerminalEvent(const string label)
{
  return (label == "SIGNAL_INIT" ||
          label == "LEVEL_REACHED" ||
          label == "LEVEL_TP_HIT" ||
          label == "INITIAL_TP_TRAILING_ARMED" ||
          label == "INITIAL_TP_TRAILING_PARTIAL" ||
          label == "INITIAL_TP_TRAILING_SIGNAL_CLOSED" ||
          label == "INITIAL_TP_TRAILING_CLOSE_FAILED" ||
          label == "TRAILING_SL_UPDATE" ||
          label == "TRAILING_TP_UPDATE" ||
          label == "TRAILING_SL_HIT" ||
          label == "TRAILING_TP_HIT" ||
          label == "TRAILING_TP_SIGNAL_CLOSED" ||
          label == "GRID_STOP_LEVEL_LIMIT" ||
          label == "LEVEL_ACTIVATION_FAILED_TARGET_LOT" ||
          label == "LEVEL_ACTIVATION_FAILED_SEND" ||
          label == "LIMIT_EXPIRED_STRUCTURE");
}

string GridBuildLevelResolutionSummary(const SignalParams &signal_params,
                                       const GridOrderState &order_state)
{
  if(Base_Strategy_Type != FIB_LEVEL_RANGE)
  {
    double distance_points = ResolveGridLevelDistancePoints(signal_params, order_state);
    return StringFormat("source=POINTS|next=%.5f|entry_ref=%.5f|distance_pts=%.2f",
                        order_state.next_level_price,
                        order_state.entry_reference_price,
                        distance_points);
  }

  double entry_price = signal_params.entry_price;
  if(entry_price <= 0.0)
    entry_price = signal_params.grid_entry_reference_price;
  if(entry_price <= 0.0)
    entry_price = order_state.entry_reference_price;
  if(entry_price <= 0.0)
  {
    return StringFormat("source=FIB|resolved=false|reason=entry_price|next=%.5f",
                        order_state.next_level_price);
  }

  double peak_price = 0.0;
  double bottom_price = 0.0;
  bool current_is_bottom = false;
  double entry_percent = 0.0;
  double band_lower = 0.0;
  double band_upper = 0.0;
  double resolved_entry_percent = 0.0;
  double resolved_entry_price = 0.0;
  bool band_target_used = false;
  bool entry_ok = ResolveFibonacciCanonicalEntryContext(signal_params,
                                                        entry_price,
                                                        entry_percent,
                                                        band_lower,
                                                        band_upper,
                                                        resolved_entry_percent,
                                                        resolved_entry_price,
                                                        peak_price,
                                                        bottom_price,
                                                        current_is_bottom,
                                                        band_target_used);
  if(!entry_ok)
  {
    return StringFormat("source=FIB|resolved=false|reason=entry_percent|entry=%.5f|next=%.5f",
                        entry_price,
                        order_state.next_level_price);
  }

  double level_percent = 0.0;
  bool level_percent_ok = ResolveFibonacciGridLevelPercent(signal_params,
                                                           order_state.level_index,
                                                           level_percent);
  double fib_level_price = 0.0;
  bool level_price_ok = ResolveFibonacciGridLevelPrice(signal_params,
                                                       order_state.level_index,
                                                       fib_level_price);
  string band_label = "n/a";
  if(band_lower != 0.0 || band_upper != 0.0)
    band_label = StringFormat("%.2f-%.2f", band_lower, band_upper);

  string next_source = "LOGICAL";
  if(level_price_ok && order_state.next_level_price > 0.0)
  {
    double next_gap_points = GridAbsolutePriceDistancePoints(order_state.next_level_price,
                                                             fib_level_price);
    if(next_gap_points > 0.1)
      next_source = "BROKER_SAFE";
  }

  int fib_steps = signal_params.fib_level_offset_steps + order_state.level_index;
  if(fib_steps <= 0)
    fib_steps = 1;

  string entry_anchor_source = "RAW";
  if(SignalHasResolvedFibonacciEntryAnchor(signal_params))
    entry_anchor_source = "SIGNAL";
  else if(band_target_used)
    entry_anchor_source = "INFERRED";

  return StringFormat("source=FIB|resolved=%s|entry=%.5f|entry_pct=%s|entry_band=%s|resolved_entry_pct=%s|resolved_entry_price=%s|entry_anchor_src=%s|level_pct=%s|logical_next_price=%s|emitted_next_price=%.5f|next_src=%s|fib_steps=%d|peak=%.5f|bottom=%.5f|current_is_bottom=%s",
                      GridBoolToken(level_percent_ok && level_price_ok),
                      entry_price,
                      GridFormatDoubleOrToken(true, entry_percent, 2),
                      band_label,
                      GridFormatDoubleOrToken(band_target_used, resolved_entry_percent, 2),
                      GridFormatDoubleOrToken(band_target_used, resolved_entry_price, 5),
                      entry_anchor_source,
                      GridFormatDoubleOrToken(level_percent_ok, level_percent, 2),
                      GridFormatDoubleOrToken(level_price_ok, fib_level_price, 5),
                      order_state.next_level_price,
                      next_source,
                      fib_steps,
                      peak_price,
                      bottom_price,
                      GridBoolToken(current_is_bottom));
}

void GridLogLevelResolutionContext(const string label,
                                   const SignalParams &signal_params,
                                   const GridOrderState &order_state)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = GridDisplayLevelNumber(order_state.level_index);
  string message = StringFormat("dir=%s|L%d|%s",
                                direction,
                                display_level,
                                GridBuildLevelResolutionSummary(signal_params, order_state));
  GridAppendQueryDebugLog(label, message);
}

void GridLogNextLevelTriggerDecision(const SignalParams &signal_params,
                                     const GridOrderState &order_state,
                                     const SignalTypes direction)
{
  string direction_label = (direction == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = GridDisplayLevelNumber(order_state.level_index);
  double entry_side_price = GridCurrentPriceForDirection(direction, true);
  double reference_price = order_state.entry_reference_price;
  if(reference_price <= 0.0)
    reference_price = signal_params.entry_price;
  if(reference_price <= 0.0)
    reference_price = signal_params.grid_entry_reference_price;

  string message = StringFormat("dir=%s|L%d|entry_side=%.5f|next=%.5f|entry_ref=%.5f|limit_armed=%s|breakout=%s|spread_pts=%.1f",
                                direction_label,
                                display_level,
                                entry_side_price,
                                order_state.next_level_price,
                                reference_price,
                                GridBoolToken(order_state.limit_activation_armed),
                                GridBoolToken(SignalUsesBreakoutLimitAnchoring(signal_params)),
                                g_points_spread);
  GridAppendQueryDebugLog("NEXT_LEVEL_TRIGGER", message);
  GridLogLevelResolutionContext("NEXT_LEVEL_CONTEXT", signal_params, order_state);
}

void GridLogStopLimitDecision(const SignalParams &signal_params,
                              const GridOrderState &order_state,
                              const int level_stop_limit,
                              const bool level_limit_hit)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = GridDisplayLevelNumber(order_state.level_index);
  string action = level_limit_hit ? "CLOSE_ALL" : "BUILD_NEXT_LEVEL";
  string message = StringFormat("dir=%s|L%d|stop_limit=%d|blocked=%s|action=%s|next=%.5f|entry_ref=%.5f|spread_pts=%.1f",
                                direction,
                                display_level,
                                level_stop_limit,
                                GridBoolToken(level_limit_hit),
                                action,
                                order_state.next_level_price,
                                order_state.entry_reference_price,
                                g_points_spread);
  GridAppendQueryDebugLog("STOP_LIMIT_DECISION", message);
}

void GridLogEvent(const string label,
                  const SignalParams &signal_params,
                  const GridOrderState &order_state)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  string direction_short = (signal_params.signal_type == BULLISH) ? "B" : "S";
  int display_level = GridDisplayLevelNumber(order_state.level_index);
  string event_timestamp = TimeToString(TimeCurrent(),
                                        TIME_DATE|TIME_SECONDS);
  string event_timestamp_min = TimeToString(TimeCurrent(),
                                            TIME_DATE|TIME_MINUTES);
  string signal_timestamp = "n/a";
  string signal_timestamp_min = "n/a";
  if(signal_params.entry_time > 0)
  {
    signal_timestamp = TimeToString(signal_params.entry_time,
                                    TIME_DATE|TIME_SECONDS);
    signal_timestamp_min = TimeToString(signal_params.entry_time,
                                        TIME_DATE|TIME_MINUTES);
  }
  string structure_timestamp = "n/a";
  string structure_timestamp_min = "n/a";
  if(signal_params.context_structure_snapshot_time > 0)
  {
    structure_timestamp = TimeToString(signal_params.context_structure_snapshot_time,
                                       TIME_DATE|TIME_SECONDS);
    structure_timestamp_min = TimeToString(signal_params.context_structure_snapshot_time,
                                           TIME_DATE|TIME_MINUTES);
  }
  string structure_audit = GridResolveStructureAuditSummary(signal_params);

  string message = StringFormat("dir=%s|L%d|status=%s|entry_ref=%.5f|next=%.5f|entry=%.5f|stop=%.5f|tp=%.5f|lot=%.2f|event_ts=%s|signal_ts=%s|structure_ts=%s|trail_sl_ts=%s|trail_tp_ts=%s|trail_arm_ts=%s|trail_armed=%s|structure=%s",
                                direction,
                                display_level,
                                EnumToString(order_state.status),
                                order_state.entry_reference_price,
                                order_state.next_level_price,
                                order_state.entry_price,
                                signal_params.trailing_stop_price,
                                order_state.take_profit_price,
                                order_state.lot_size,
                                event_timestamp,
                                signal_timestamp,
                                structure_timestamp,
                                TimeToString(signal_params.trailing_last_sl_structure_time, TIME_DATE|TIME_SECONDS),
                                TimeToString(signal_params.trailing_last_tp_structure_time, TIME_DATE|TIME_SECONDS),
                                TimeToString(signal_params.trailing_structure_arm_time, TIME_DATE|TIME_SECONDS),
                                signal_params.trailing_structure_armed ? "true" : "false",
                                structure_audit);

  GridAppendQueryDebugLog(label, message);

  if(label == "SIGNAL_INIT" || label == "LEVEL_PENDING_INIT")
    GridLogLevelResolutionContext("LEVEL_CONTEXT", signal_params, order_state);

  if(Enable_Logs && GridShouldPrintTerminalEvent(label))
  {
    PrintFormat("[%s] %s L%d ev=%s sg=%s st=%s",
                label,
                direction_short,
                display_level,
                event_timestamp_min,
                signal_timestamp_min,
                structure_timestamp_min);
    PrintFormat("[STRUCT] %s", structure_audit);
  }
}

void GridLogGuardrailBlock(const string label,
                           const SignalParams &signal_params,
                           const GridOrderState &order_state,
                           const string reason)
{
  string direction = (signal_params.signal_type == BULLISH) ? "BULLISH" : "BEARISH";
  int display_level = GridDisplayLevelNumber(order_state.level_index);
  string message = StringFormat("dir=%s|L%d|status=%s|reason=%s",
                                direction,
                                display_level,
                                EnumToString(order_state.status),
                                reason);
  GridAppendQueryDebugLog(label, message);
}

#endif // _MICROSERVICES_TRADING_SIGNALS_GRID_ORDER_LOGGING_MQH_
